// 1. Import required modules
local { Game } = require("HeatedMetal");
local math = require("math"); // Import math library, though not heavily used in this simplified version

// 2. Define module-level variables and constants
local playerEntity = null;     // Stores the local player entity
local previousOrigin = null;   // Stores the player's origin from the previous frame to calculate velocity
local isJumping = false;       // Is the player currently in an active jump (upward or downward phase initiated by jump)
local verticalVelocity = 0.0;  // Current vertical speed of the player
local jumpHorizontalVelocity = Vector2(0,0); // Horizontal velocity at the start of the jump, maintained in air

// --- Physics and Control Parameters (TWEAK THESE FOR DESIRED FEEL) ---

// IMPORTANT NOTE ON SCRIPT GRAVITY vs. GAME GRAVITY:
// This script applies its own 'gravity' value to the player's vertical velocity.
// If the game engine also applies its own gravity to the player entity,
// you might experience a "double gravity" effect, making the player fall too fast.
//
// TO COMPENSATE FOR GAME'S BUILT-IN GRAVITY:
// - You will likely need to set this script's 'gravity' to a VERY LOW POSITIVE VALUE.
// - Start with a small value (e.g., 1.0 or 2.0) and observe.
// - If the player still falls too fast, reduce it further.
// - If the game's gravity is strong and you want a "floatier" jump controlled by this script,
//   this script's 'gravity' might even need to be 0 or a very small negative value
//   (acting as a slight upward lift to counteract some of the game's gravity).
//   However, a negative script gravity means you are actively fighting the game's physics.
//
// The goal is to tune this 'gravity' so the COMBINED effect results in the desired fall speed.
local gravity = 2.0;  // Script-applied gravitational acceleration. START LOW if game has its own gravity.
                      // Default was 5.0, try significantly lower if double gravity is an issue.

local jumpStrength = 4.0;      // Initial upward velocity for a jump. This determines how high the jump is AGAINST the net gravity.
// This factor determines what proportion of the player's current horizontal speed
// is transferred into the jump when they take off.
// 1.0 = full inertia transfer, 0.5 = half inertia, 0.0 = vertical jump with no horizontal carry-over.
local JUMP_HORIZONTAL_INERTIA_TRANSFER_RATIO = 0.7;

local groundCheckDistance = 0.3; // Raycast distance downwards to check for ground
local groundSnapOffset = 0.05; // Small offset for raycast origins and landing snap tolerance

// 3. Initialize the jump system, get the player entity
function InitializeJumpSystem() {
    isJumping = false;
    verticalVelocity = 0.0;
    jumpHorizontalVelocity = Vector2(0,0); // Reset horizontal jump velocity
    previousOrigin = null; // Reset previous origin

    local localPlayer = Game.GetLocalPlayer();
    if (localPlayer) {
        playerEntity = localPlayer.Entity();
        if (playerEntity) {
            print("JumpSystem: Player entity found.");
            previousOrigin = playerEntity.GetOrigin(); // Initialize previousOrigin
        } else {
            print("JumpSystem WARNING: Could not get local player entity.");
        }
    } else {
        print("JumpSystem WARNING: Could not get local player controller.");
        playerEntity = null;
    }
}

// 4. Get ground information (is on ground, and ground's Z coordinate)
// Returns: table { hit: bool, groundZ: float (if hit is true) }
function GetGroundInfo(currentX, currentY, currentZ) {
    if (!playerEntity) return { hit = false, groundZ = 0.0 };

    // Raycast start point slightly above the player's current Z to avoid starting inside geometry
    local rayStart = Vector3(currentX, currentY, currentZ + groundSnapOffset);
    // Raycast end point slightly below the player's current Z
    local rayEnd = Vector3(currentX, currentY, currentZ - groundCheckDistance);

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
    local dt = DeltaTime();                         // Get time since last frame

    if (dt <= 0) dt = 1.0/60.0; // Prevent issues if DeltaTime is zero or negative

    // Get ground info based on current position
    local groundInfo = GetGroundInfo(currentOrigin.x, currentOrigin.y, currentOrigin.z);
    local onGroundThisFrame = groundInfo.hit;

    // Calculate current frame's horizontal velocity if previousOrigin exists
    local currentFrameHorizontalVelocity = Vector2(0,0);
    if (previousOrigin != null && dt > 0) {
        currentFrameHorizontalVelocity.x = (currentOrigin.x - previousOrigin.x) / dt;
        currentFrameHorizontalVelocity.y = (currentOrigin.y - previousOrigin.y) / dt; // Assuming Y is a horizontal world-axis
    }

    // Handle jump input
    if (IsKeyPressed("Space") && onGroundThisFrame && !isJumping) {
        isJumping = true;
        verticalVelocity = jumpStrength;
        // Capture and scale horizontal velocity at jump start using the transfer ratio
        jumpHorizontalVelocity.x = currentFrameHorizontalVelocity.x * JUMP_HORIZONTAL_INERTIA_TRANSFER_RATIO;
        jumpHorizontalVelocity.y = currentFrameHorizontalVelocity.y * JUMP_HORIZONTAL_INERTIA_TRANSFER_RATIO;
        // print("Player jumped! Initial V-Velocity: " + verticalVelocity + " H-Velocity: " + jumpHorizontalVelocity.x + "," + jumpHorizontalVelocity.y);
    }

    local newPosition = currentOrigin; // Start with current position for modification

    if (!onGroundThisFrame || isJumping) { // If player is in the air (either from jumping or falling)
        // --- Apply Vertical Physics ---
        verticalVelocity -= gravity * dt; // Apply script's gravity
        newPosition.z = currentOrigin.z + (verticalVelocity * dt);

        // --- Apply Horizontal Inertia ---
        newPosition.x = currentOrigin.x + (jumpHorizontalVelocity.x * dt);
        newPosition.y = currentOrigin.y + (jumpHorizontalVelocity.y * dt); // Assuming Y is a horizontal world-axis

        // --- Precise Landing Check (using the new predicted X, Y for the raycast) ---
        // Raycast from slightly above where the player WILL BE to slightly below where they WILL BE.
        local landingCheckRayStart = Vector3(newPosition.x, newPosition.y, newPosition.z + groundSnapOffset * 2);
        local landingCheckRayEnd = Vector3(newPosition.x, newPosition.y, newPosition.z - groundCheckDistance);
        local landingRayResult = Game.Raycast(landingCheckRayStart, landingCheckRayEnd, 1);

        if (landingRayResult.DidHit() && landingRayResult.Hits().len() > 0) {
            local hitGroundZ = landingRayResult.Hits()[0].Origin().z;
            // If the predicted Z position (after applying script gravity and velocity for this frame)
            // is at or below the detected ground, and we are moving downwards.
            if (newPosition.z <= hitGroundZ + groundSnapOffset && verticalVelocity <= 0) {
                newPosition.z = hitGroundZ; // Snap to the actual ground Z
                // Apply a small negative velocity on landing to help "stick" the player
                // This helps prevent bouncing if ground detection is slightly inconsistent next frame.
                verticalVelocity = -0.5; // Small downward nudge, adjust if too sticky or not enough
                isJumping = false;          // Landed
                jumpHorizontalVelocity = Vector2(0,0); // Reset horizontal jump velocity on land
                // print("Player landed at Z: " + newPosition.z);
            }
            // If not landing (e.g., still moving up, or predicted Z is still above hitGroundZ),
            // newPosition.z remains as calculated by script's physics.
        }
        // If no ground hit by landing ray, newPosition remains as calculated (player continues in air).

    } else { // Player is on the ground and not trying to jump
        // If player was falling slightly due to the landing nudge, or just on ground
        if (verticalVelocity < 0 && onGroundThisFrame) { // If recently landed and still has small negative velocity
             verticalVelocity = 0; // Fully stop vertical velocity once confirmed on ground next frame
        } else if (onGroundThisFrame) { // If already stable on ground
            verticalVelocity = 0;
        }
        // else: if somehow !onGroundThisFrame but also !isJumping, this case is handled by the block above.

        if (math.abs(currentOrigin.z - groundInfo.groundZ) > 0.001) { // Check for small tolerance
             newPosition.z = groundInfo.groundZ; // Snap to ground
        } else {
             newPosition.z = currentOrigin.z; // Already close enough, no change needed to prevent jitter
        }
        isJumping = false; // Ensure jumping state is definitely false
        jumpHorizontalVelocity = Vector2(0,0); // Reset horizontal jump velocity when on ground and not jumping
    }

    playerEntity.SetOrigin(newPosition); // Set the player's new origin
    previousOrigin = Vector3(newPosition.x, newPosition.y, newPosition.z); // Update previousOrigin for the next frame
}

// 6. Main logic / initialization function
function Main() {
    print("HeatedMetal Player Jump Script Loaded (with Horizontal Inertia).");
    InitializeJumpSystem(); // Initialize on first load

    // Register callbacks
    AddCallback_Update(UpdateJump);
    // Re-initialize player entity on round start or player spawn
    AddCallback_RoundStart(InitializeJumpSystem);
    AddCallback_PlayerSpawn(InitializeJumpSystem);

    print("Callbacks registered for jump system.");
}

// 7. Call the main function (module entry point)
Main();
