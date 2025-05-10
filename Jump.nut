// 1. Import required modules
local { Game } = require("HeatedMetal");
local math = require("math"); // Import math library, though not heavily used in this simplified version

// 2. Define module-level variables and constants
local playerEntity = null;     // Stores the local player entity
local isJumping = false;       // Is the player currently in an active jump (upward or downward phase initiated by jump)
local verticalVelocity = 0.0;  // Current vertical speed of the player
local gravity = 5.0;          // Gravitational acceleration (reduced to slow down fall)
local jumpStrength = 4.0;      // Initial upward velocity for a jump (tweak for jump height)
local groundCheckDistance = 0.3; // Raycast distance downwards to check for ground (slightly increased for robustness)
local groundSnapOffset = 0.05; // Small offset for raycast origins and landing snap tolerance

// 3. Initialize the jump system, get the player entity
function InitializeJumpSystem() {
    isJumping = false;
    verticalVelocity = 0.0;
    local localPlayer = Game.GetLocalPlayer();
    if (localPlayer) {
        playerEntity = localPlayer.Entity();
        if (playerEntity) {
            print("JumpSystem: Player entity found.");
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

    // Handle jump input
    if (IsKeyPressed("Space") && onGroundThisFrame && !isJumping) {
        isJumping = true;
        verticalVelocity = jumpStrength;
        // print("Player jumped!");
    }

    local newVerticalPosition = currentOrigin.z;

    if (!onGroundThisFrame || isJumping) { // If player is in the air (either from jumping or falling)
        verticalVelocity -= gravity * dt; // Apply gravity

        // Calculate the predicted next Z position
        local predictedNextZ = currentOrigin.z + (verticalVelocity * dt);

        // Perform a new ground check from slightly above the *predicted* next Z position
        // This helps to see if we are about to land
        local landingCheckRayStart = Vector3(currentOrigin.x, currentOrigin.y, predictedNextZ + groundSnapOffset * 2); // Start higher for landing check
        local landingCheckRayEnd = Vector3(currentOrigin.x, currentOrigin.y, predictedNextZ - groundCheckDistance);
        local landingRayResult = Game.Raycast(landingCheckRayStart, landingCheckRayEnd, 1);

        if (landingRayResult.DidHit() && landingRayResult.Hits().len() > 0) {
            local hitGroundZ = landingRayResult.Hits()[0].Origin().z;
            // If predicted Z is at or below the detected ground, and we are moving downwards
            if (predictedNextZ <= hitGroundZ + groundSnapOffset && verticalVelocity <= 0) {
                newVerticalPosition = hitGroundZ; // Snap to the actual ground Z
                verticalVelocity = 0;           // Stop vertical movement
                isJumping = false;              // Landed, so no longer in an active jump
                // print("Player landed.");
            } else {
                // Not landing yet, or still moving upwards towards ground (e.g. jumping up a slope)
                newVerticalPosition = predictedNextZ;
            }
        } else {
            // No ground detected below the predicted position, continue falling
            newVerticalPosition = predictedNextZ;
        }
    } else { // Player is on the ground and not trying to jump
        verticalVelocity = 0;
        // Snap to the detected ground Z to prevent jitter and ensure stability
        // Only snap if there's a slight difference to avoid continuous SetOrigin calls
        if (math.abs(currentOrigin.z - groundInfo.groundZ) > 0.001) {
             newVerticalPosition = groundInfo.groundZ;
        } else {
             newVerticalPosition = currentOrigin.z; // Already close enough
        }
        isJumping = false; // Ensure jumping state is false if on ground
    }

    // Set the player's new origin with the calculated vertical position
    playerEntity.SetOrigin(Vector3(currentOrigin.x, currentOrigin.y, newVerticalPosition));
}

// 6. Main logic / initialization function
function Main() {
    print("HeatedMetal Player Jump Script Loaded (Simplified Fall & Landing).");
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
