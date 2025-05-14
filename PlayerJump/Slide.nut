// 1. Import required modules
local { Game } = require("HeatedMetal");
local math = require("math"); // Import math library for operations like sqrt

// --- Shared Character State Variables (assumed to be accessible by jump script too) ---
local playerEntity = null;     // Stores the local player entity
local previousOrigin = null;   // Stores the player's origin from the previous frame
local isJumping = false;       // Is the player currently in an active jump (managed by jump script)
local verticalVelocity = 0.0;  // Current vertical speed of the player (managed by jump script)
local currentHorizontalVelocity = Vector2(0,0); // Player's current horizontal velocity (managed by jump/air control script)

// --- Slide State Variables ---
local isSliding = false;           // Is the player currently sliding?
local slideDirection = Vector3(0,0,0); // World-space direction of the slide
local currentSlideSpeed = 0.0;     // Current speed of the slide
local slideDuration = 0.0;         // How long the current slide has lasted

// --- Slide Control Parameters (tweak for desired feel) ---
local SLIDE_KEY = "C";                     // Key to initiate slide
local CAN_SLIDE_FROM_SPRINT_ONLY = true;   // Must be sprinting to slide
local INITIAL_SLIDE_SPEED_BOOST_FACTOR = 1.1; // Multiplier for current speed at slide start (if not using base speed)
local SLIDE_BASE_SPEED = 5.0;              // Base speed if not boosting or if current speed is too low
local SLIDE_DECELERATION = 1.0;            // How quickly the slide slows down
local MIN_SLIDE_SPEED = 1.0;               // Slide ends if speed drops below this
local MAX_SLIDE_DURATION = 1.0;            // Maximum duration of a slide in seconds
local SLIDE_WALL_CHECK_DISTANCE = 0.4;     // How far ahead to check for walls during slide
local SLIDE_PLAYER_HEIGHT_FACTOR = 0.5;    // Hypothetical factor to reduce player height/camera (e.g., 0.5 for half height)
local SLIDE_COOLDOWN = 1.0;                // Cooldown in seconds between slides
local lastSlideEndTime = 0.0;              // Timestamp of when the last slide finished

// --- Sprinting State (MUST BE MANAGED BY YOUR MOVEMENT LOGIC) ---
// !!! IMPORTANT: 'isSprinting' MUST be set to true by your other game logic when the player is actually sprinting.
// !!! This script DOES NOT automatically detect sprinting.
local isSprinting = false; // This global variable should ideally be set by your main movement controller.

// --- Global Game Timer for Cooldowns ---
local gameTime = 0.0;

// 3. Initialize Character System (call this at start and round/spawn events)
function InitializeCharacterSystem() {
    // Initialize jump variables (if this function is shared with jump script)
    isJumping = false;
    verticalVelocity = 0.0;
    currentHorizontalVelocity = Vector2(0,0);

    // Initialize slide variables
    isSliding = false;
    currentSlideSpeed = 0.0;
    slideDuration = 0.0;
    lastSlideEndTime = -SLIDE_COOLDOWN; // Allow sliding immediately at start

    previousOrigin = null;
    gameTime = 0.0; // Reset game time as well, or manage it truly globally if needed

    local localPlayer = Game.GetLocalPlayer();
    if (localPlayer) {
        playerEntity = localPlayer.Entity();
        if (playerEntity) {
            print("CharacterSystem: Player entity found.");
            previousOrigin = playerEntity.GetOrigin();
        } else {
            print("CharacterSystem WARNING: Could not get local player entity.");
        }
    } else {
        print("CharacterSystem WARNING: Could not get local player controller.");
        playerEntity = null;
    }
}

// 4. Get ground information (re-use from jump script or define here)
// Parameters: current world X, Y, Z coordinates to check from
// Returns: table { hit: bool, groundZ: float (if hit is true) }
function GetGroundInfo(checkX, checkY, checkZ) {
    if (!playerEntity) return { hit = false, groundZ = 0.0 };
    local rayStart = Vector3(checkX, checkY, checkZ + 0.05); // groundSnapOffset equivalent
    local rayEnd = Vector3(checkX, checkY, checkZ - 0.3);   // groundCheckDistance equivalent
    local rayResult = Game.Raycast(rayStart, rayEnd, 1);
    if (rayResult.DidHit() && rayResult.Hits().len() > 0) {
        return { hit = true, groundZ = rayResult.Hits()[0].Origin().z };
    }
    return { hit = false, groundZ = 0.0 };
}

// --- Slide Helper Functions ---
function StartSlide(currentOrigin, frameHorizontalSpeed) {
    isSliding = true;
    slideDuration = 0.0;

    // Determine slide direction
    local playerForward = playerEntity.GetForward();
    // Prioritize current movement direction if significant, otherwise player facing direction
    if (frameHorizontalSpeed > 0.1 && previousOrigin != null) { // If player was moving
        local moveVec = Vector3(currentOrigin.x - previousOrigin.x, currentOrigin.y - previousOrigin.y, 0);
        if (moveVec.LengthSq() > 0.0001) {
            slideDirection = moveVec.Normalize();
        } else { // Fallback to player forward if moveVec is too small (e.g. spinning on spot)
            slideDirection = Vector3(playerForward.x, playerForward.y, 0).Normalize();
        }
    } else { // Default to player forward direction
        slideDirection = Vector3(playerForward.x, playerForward.y, 0).Normalize();
    }

    // Set initial slide speed
    currentSlideSpeed = math.max(frameHorizontalSpeed * INITIAL_SLIDE_SPEED_BOOST_FACTOR, SLIDE_BASE_SPEED);
    currentSlideSpeed = math.min(currentSlideSpeed, SLIDE_BASE_SPEED * 1.5); // Cap initial speed

    print("[DEBUG] Slide Started! Speed: " + currentSlideSpeed + " Direction: " + slideDirection.x +","+slideDirection.y);
    // TODO: LowerPlayerView(true); // Hypothetical function to lower camera/hitbox
    // TODO: Play slide start sound
}

function EndSlide() {
    if (!isSliding) return;
    isSliding = false;
    currentSlideSpeed = 0.0;
    lastSlideEndTime = gameTime; // Use our global gameTime
    print("[DEBUG] Slide Ended. Cooldown started at gameTime: " + gameTime);
    // TODO: LowerPlayerView(false); // Hypothetical function to restore camera/hitbox
    // TODO: Play slide end sound
}

// 5. Update Slide Logic (call this every frame in the main Update callback)
function UpdateSlide() {
    if (!playerEntity) return; // No player, no slide

    local currentOrigin = playerEntity.GetOrigin();
    local dt = DeltaTime();
    if (dt <= 0) dt = 1.0/60.0;

    local groundInfo = GetGroundInfo(currentOrigin.x, currentOrigin.y, currentOrigin.z);
    local onGround = groundInfo.hit;

    // --- Handle Slide State ---
    if (isSliding) {
        slideDuration += dt;
        currentSlideSpeed -= SLIDE_DECELERATION * dt;
        currentSlideSpeed = math.max(0, currentSlideSpeed); // Ensure speed doesn't go negative

        // Check for wall collision
        local slideCheckOriginOffsetZ = -0.3; // Offset Z for raycast start, assuming player is lowered
        local wallCheckStartPos = Vector3(currentOrigin.x, currentOrigin.y, currentOrigin.z + slideCheckOriginOffsetZ);
        local wallHitRay = Game.Raycast(wallCheckStartPos, wallCheckStartPos + slideDirection * SLIDE_WALL_CHECK_DISTANCE, 1);

        // Conditions to end slide
        if (!onGround || currentSlideSpeed <= MIN_SLIDE_SPEED || slideDuration >= MAX_SLIDE_DURATION || wallHitRay.DidHit()) {
            if(!onGround) print("[DEBUG] Slide ended: Not on ground.");
            if(currentSlideSpeed <= MIN_SLIDE_SPEED) print("[DEBUG] Slide ended: Speed too low ("+currentSlideSpeed+").");
            if(slideDuration >= MAX_SLIDE_DURATION) print("[DEBUG] Slide ended: Max duration reached ("+slideDuration+").");
            if(wallHitRay.DidHit()) print("[DEBUG] Slide ended: Wall hit.");
            EndSlide();
        } else {
            // Apply slide movement
            local finalPos = currentOrigin;
            finalPos += slideDirection * currentSlideSpeed * dt;

            // Keep on ground (simple snap)
            local nextGroundInfo = GetGroundInfo(finalPos.x, finalPos.y, finalPos.z); // Check at new H pos
            if (nextGroundInfo.hit) {
                finalPos.z = nextGroundInfo.groundZ;
            } else { // Slid off an edge
                print("[DEBUG] Slide ended: Slid off edge.");
                EndSlide();
                // The jump script's falling logic should take over if !onGround
            }
            playerEntity.SetOrigin(finalPos);
        }
    } else {
        // --- Try to Initiate Slide ---
        local currentFrameHorizontalSpeed = 0.0;
        if (previousOrigin != null && dt > 0) {
            local dx = (currentOrigin.x - previousOrigin.x);
            local dy = (currentOrigin.y - previousOrigin.y);
            currentFrameHorizontalSpeed = math.sqrt(dx*dx + dy*dy) / dt;
        }

        // --- Sprinting State Estimation (EXAMPLE ONLY - REPLACE WITH YOUR ACTUAL SPRINT LOGIC) ---
        // This section attempts to guess if the player is sprinting based on speed.
        // It's a placeholder and might not be accurate for your game's specific sprinting mechanics.
        // Ideally, your main movement controller should set the global 'isSprinting' variable.
        local SPRINT_SPEED_THRESHOLD = 4.0; // Define a speed that you consider to be sprinting. Adjust this value.
        if (currentFrameHorizontalSpeed > SPRINT_SPEED_THRESHOLD && IsKeyPressed("W")) { // Example: sprinting if moving fast AND holding W
            isSprinting = true;
        } else {
            isSprinting = false;
        }
        // You can uncomment the next line to see the estimated sprint state and speed.
        // print("[DEBUG] Estimated isSprinting: " + isSprinting + " (Speed: " + currentFrameHorizontalSpeed + ")");
        // --- End Sprinting State Estimation ---


        local timeSinceLastSlide = gameTime - lastSlideEndTime;
        local canInitiateSlide = onGround && !isJumping && (timeSinceLastSlide >= SLIDE_COOLDOWN);

        if (CAN_SLIDE_FROM_SPRINT_ONLY) {
            canInitiateSlide = canInitiateSlide && isSprinting;
        }

        // Debug print for slide initiation conditions
        if (IsKeyPressed(SLIDE_KEY)) {
            print("[DEBUG] Slide Attempt: KeyPressed(" + SLIDE_KEY + ")=true");
            print("[DEBUG] Conditions: onGround=" + onGround +
                  ", !isJumping=" + (!isJumping) +
                  ", cooldownMet=" + (timeSinceLastSlide >= SLIDE_COOLDOWN) + " (timeSince: "+timeSinceLastSlide+" gameTime: "+gameTime+" lastSlide: "+lastSlideEndTime+")" +
                  (CAN_SLIDE_FROM_SPRINT_ONLY ? (", isSprinting=" + isSprinting) : ("")));
            if (CAN_SLIDE_FROM_SPRINT_ONLY && !isSprinting) {
                 print("[DEBUG] Slide Fail: CAN_SLIDE_FROM_SPRINT_ONLY is true, but isSprinting is false.");
            }
        }


        if (IsKeyPressed(SLIDE_KEY) && canInitiateSlide) {
            StartSlide(currentOrigin, currentFrameHorizontalSpeed);
        }
    }
}


// --- Main Update Function (to be called by AddCallback_Update) ---
// This function would also call UpdateJump if you have a jump script
function MasterUpdate() {
    if (!playerEntity) {
        InitializeCharacterSystem(); // Attempt to get player entity if lost
        if (!playerEntity) return;
    }

    local currentDt = DeltaTime(); // Get dt once for the frame
    if (currentDt <= 0) currentDt = 1.0/60.0; // Ensure dt is positive

    gameTime += currentDt; // Update global game timer

    // --- Hypothetical Jump Update Call (ensure it checks for !isSliding) ---
    // print("[DEBUG] MasterUpdate: Calling UpdateJump (if implemented)");
    // UpdateJump(); // Your jump logic would go here, pass currentDt

    // --- Slide Update Call ---
    // print("[DEBUG] MasterUpdate: Calling UpdateSlide");
    UpdateSlide(); // UpdateSlide already gets dt via DeltaTime() internally


    // --- Update previousOrigin at the very end ---
    // This must be after ALL position modifications in the frame
    if (playerEntity) { // Check again in case player entity became null during updates
        previousOrigin = playerEntity.GetOrigin();
    }
}


// 6. Main logic / initialization function
function Main() {
    print("HeatedMetal Player Slide Script Loaded (with Debugging).");
    InitializeCharacterSystem(); // Initialize on first load

    // Register callbacks
    AddCallback_Update(MasterUpdate); // Call MasterUpdate which then calls UpdateSlide (and UpdateJump)
    // Re-initialize character system on round start or player spawn
    AddCallback_RoundStart(InitializeCharacterSystem);
    AddCallback_PlayerSpawn(InitializeCharacterSystem);

    print("Callbacks registered for MasterUpdate.");
}

// 7. Call the main function (module entry point)
Main();
