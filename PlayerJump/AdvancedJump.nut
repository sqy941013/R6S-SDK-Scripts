// 1. Import required modules
local { Game } = require("HeatedMetal");
local math = require("math"); // Import math library for operations like sqrt

// 2. Define module-level variables and constants
local playerEntity = null;     // Stores the local player entity
local previousOrigin = null;   // Stores the player's origin from the previous frame
local isJumping = false;       // Is the player currently in an active jump (initiated by jump key, until landing)
local verticalVelocity = 0.0;  // Current vertical speed of the player
local currentHorizontalVelocity = Vector2(0,0); // Player's current horizontal velocity (world space X,Y)

// --- Physics and Control Parameters (tweak these for desired feel) ---
local gravity = 5.0;                // Gravitational acceleration (e.g., 9.8, 12.0, 20.0)
local jumpStrength = 4.0;           // Initial upward velocity for a jump (e.g., 4.0, 5.0, 7.0)

local groundCheckDistance = 0.3;    // Raycast distance downwards to check for ground
local groundSnapOffset = 0.05;      // Small offset for raycast origins and landing snap tolerance

local airControlAcceleration = 3.0;// How quickly player can change direction/accelerate in air (e.g., 15.0, 25.0)
local airDragValue = 2.5;           // How much air slows down horizontal movement (e.g., 1.0 for low drag, 5.0 for high drag)
                                    // This value is used in: factor = 1.0 - (airDragValue * dt)
local maxAirSpeed = 1.0;            // Maximum horizontal speed achievable in air via control (e.g., 5.0, 7.0)


// 3. Initialize the jump system, get the player entity
function InitializeJumpSystem() {
    isJumping = false;
    verticalVelocity = 0.0;
    currentHorizontalVelocity = Vector2(0,0); // Reset horizontal velocity
    previousOrigin = null; // Reset previous origin

    local localPlayer = Game.GetLocalPlayer();
    if (localPlayer) {
        playerEntity = localPlayer.Entity();
        if (playerEntity) {
            print("JumpSystem: Player entity found.");
            // Initialize previousOrigin here if playerEntity is valid
            previousOrigin = playerEntity.GetOrigin();
        } else {
            print("JumpSystem WARNING: Could not get local player entity.");
        }
    } else {
        print("JumpSystem WARNING: Could not get local player controller.");
        playerEntity = null;
    }
}

// 4. Get ground information (is on ground, and ground's Z coordinate)
// Parameters: current world X, Y, Z coordinates to check from
// Returns: table { hit: bool, groundZ: float (if hit is true) }
function GetGroundInfo(checkX, checkY, checkZ) {
    if (!playerEntity) return { hit = false, groundZ = 0.0 };

    // Raycast start point slightly above the check Z to avoid starting inside geometry
    local rayStart = Vector3(checkX, checkY, checkZ + groundSnapOffset);
    // Raycast end point slightly below the check Z
    local rayEnd = Vector3(checkX, checkY, checkZ - groundCheckDistance);

    local rayResult = Game.Raycast(rayStart, rayEnd, 1); // 1 means max 1 hit

    if (rayResult.DidHit() && rayResult.Hits().len() > 0) {
        return { hit = true, groundZ = rayResult.Hits()[0].Origin().z };
    }
    return { hit = false, groundZ = 0.0 };
}

// 5. Update jump logic every frame
function UpdateJump() {
    // If player entity doesn't exist, try to re-initialize
    if (!playerEntity) {
        InitializeJumpSystem();
        if (!playerEntity) return; // If still no entity, skip further logic
    }

    local currentOrigin = playerEntity.GetOrigin();
    local dt = DeltaTime(); // Get time since last frame

    if (dt <= 0) dt = 1.0/60.0; // Prevent issues if DeltaTime is zero or negative

    // --- Calculate horizontal movement from the last frame (for jump takeoff momentum) ---
    local frameHorizontalMovementDelta = Vector2(0,0);
    if (previousOrigin != null) {
        frameHorizontalMovementDelta.x = (currentOrigin.x - previousOrigin.x);
        frameHorizontalMovementDelta.y = (currentOrigin.y - previousOrigin.y); // Assuming Y is a horizontal world-axis
    }

    // Get ground info based on current position
    local groundInfo = GetGroundInfo(currentOrigin.x, currentOrigin.y, currentOrigin.z);
    local onGround = groundInfo.hit;

    // --- Handle Jump Input ---
    if (IsKeyPressed("Space") && onGround && !isJumping) {
        isJumping = true; // Mark that a jump has been initiated
        verticalVelocity = jumpStrength;
        // Inherit horizontal momentum from ground movement at the point of jump
        if (dt > 0) { // Avoid division by zero if dt was 0
            currentHorizontalVelocity.x = frameHorizontalMovementDelta.x / dt;
            currentHorizontalVelocity.y = frameHorizontalMovementDelta.y / dt;
        } else {
            currentHorizontalVelocity.x = 0;
            currentHorizontalVelocity.y = 0;
        }
        // print("Player jumped with H-speed: " + currentHorizontalVelocity.x + ", " + currentHorizontalVelocity.y);
    }

    local finalPos = currentOrigin; // Start with current position for modification

    if (onGround) {
        if (!isJumping) { // Player is on the ground and not in the upward phase of a jump
            verticalVelocity = 0; // Reset vertical velocity
            finalPos.z = groundInfo.groundZ; // Snap to ground

            // On ground, horizontal movement is primarily driven by the base game's input/controller.
            // This script's `currentHorizontalVelocity` is mainly for air.
            // If we want to simulate "sliding" from a previous jump, we could decay `currentHorizontalVelocity` here.
            // For now, let's assume ground movement resets/overrides air momentum quickly.
            // The `frameHorizontalMovementDelta` reflects what the base game did.
            // If player stops inputting, `frameHorizontalMovementDelta` will be near zero.
            if (dt > 0) {
                 currentHorizontalVelocity.x = frameHorizontalMovementDelta.x / dt;
                 currentHorizontalVelocity.y = frameHorizontalMovementDelta.y / dt;
            } else {
                 currentHorizontalVelocity.x = 0;
                 currentHorizontalVelocity.y = 0;
            }


        } else { // Player is in the initial upward phase of a jump but still considered "onGround" (e.g., jumping up a slope)
            verticalVelocity -= gravity * dt; // Apply gravity
            finalPos.z += verticalVelocity * dt;

            // Horizontal movement from jump momentum (and potentially air control if added here too)
            // For now, just use the initiated jump momentum
            finalPos.x += currentHorizontalVelocity.x * dt;
            finalPos.y += currentHorizontalVelocity.y * dt;

            // If we've stopped moving up (or are moving down) but are still "onGround" due to slope, transition out of jump
            if (verticalVelocity <= 0) {
                isJumping = false;
                finalPos.z = groundInfo.groundZ; // Snap to the ground we are on
                verticalVelocity = 0;
            }
        }
    } else { // Player is In Air
        isJumping = true; // If not on ground, player is effectively in an "airborne" state, could be from jump or fall.

        // --- Air Control ---
        local wishDir = Vector3(0,0,0); // This will be the world-space direction player wants to move
        local playerForward = playerEntity.GetForward();
        local playerRight = playerEntity.GetRight();

        // Project player's forward and right vectors onto the horizontal plane (XY) and normalize
        // This ensures air control is purely horizontal relative to player's facing, not affected by looking up/down.
        local horizontalForward = Vector3(playerForward.x, playerForward.y, 0).Normalize();
        local horizontalRight = Vector3(playerRight.x, playerRight.y, 0).Normalize();


        if (IsKeyPressed("W")) wishDir += horizontalForward;
        if (IsKeyPressed("S")) wishDir -= horizontalForward;
        if (IsKeyPressed("A")) wishDir -= horizontalRight;
        if (IsKeyPressed("D")) wishDir += horizontalRight;

        if (wishDir.LengthSq() > 0.001) { // If there's input
            wishDir.Normalize(); // Normalize the combined direction vector

            // Accelerate in the wished direction
            currentHorizontalVelocity.x += wishDir.x * airControlAcceleration * dt;
            currentHorizontalVelocity.y += wishDir.y * airControlAcceleration * dt;
        }

        // --- Air Drag ---
        // Apply drag factor: (1 - k*dt). If k*dt >= 1, velocity becomes 0 or flips.
        // A common way is v = v * (drag ^ dt) or v = v / (1 + drag_per_second * dt)
        // Simpler: v = v * (1 - drag_constant_per_frame_if_dt_is_fixed)
        // For variable dt:
        local dragMultiplier = 1.0 - (airDragValue * dt);
        if (dragMultiplier < 0) dragMultiplier = 0; // Prevent velocity inversion
        currentHorizontalVelocity.x *= dragMultiplier;
        currentHorizontalVelocity.y *= dragMultiplier;

        // --- Speed Cap (Horizontal Air Speed) ---
        local speedSq = currentHorizontalVelocity.x * currentHorizontalVelocity.x + currentHorizontalVelocity.y * currentHorizontalVelocity.y;
        if (speedSq > maxAirSpeed * maxAirSpeed) {
            local speed = math.sqrt(speedSq);
            currentHorizontalVelocity.x = (currentHorizontalVelocity.x / speed) * maxAirSpeed;
            currentHorizontalVelocity.y = (currentHorizontalVelocity.y / speed) * maxAirSpeed;
        }

        // --- Apply horizontal air movement ---
        finalPos.x += currentHorizontalVelocity.x * dt;
        finalPos.y += currentHorizontalVelocity.y * dt;

        // --- Vertical Movement (Gravity) ---
        verticalVelocity -= gravity * dt;
        finalPos.z += verticalVelocity * dt;

        // --- Landing Check (see if new finalPos.z is below or at ground level) ---
        // Check from the new horizontal position, but the Z we are about to land on.
        local landingCheckInfo = GetGroundInfo(finalPos.x, finalPos.y, finalPos.z);
        if (landingCheckInfo.hit && finalPos.z <= landingCheckInfo.groundZ + groundSnapOffset && verticalVelocity <= 0) {
            finalPos.z = landingCheckInfo.groundZ; // Snap to ground
            verticalVelocity = 0;
            isJumping = false; // Landed
            // print("Player landed from air.");
            // Optionally, reduce horizontal velocity on landing (landing friction)
            // currentHorizontalVelocity.x *= 0.5; // Example: halve speed on land
            // currentHorizontalVelocity.y *= 0.5;
        }
    }

    playerEntity.SetOrigin(finalPos);
    previousOrigin = Vector3(finalPos.x, finalPos.y, finalPos.z); // Store the new position as previous for next frame
}

// 6. Main logic / initialization function
function Main() {
    print("HeatedMetal Player Jump Script Loaded (Air Control & Drag).");
    InitializeJumpSystem(); // Initialize on first load

    // Register callbacks
    AddCallback_Update(UpdateJump);
    // Re-initialize player entity on round start or player spawn
    AddCallback_RoundStart(InitializeJumpSystem);
    AddCallback_PlayerSpawn(InitializeJumpSystem);

    print("Callbacks registered.");
}

// 7. Call the main function (module entry point)
Main();
