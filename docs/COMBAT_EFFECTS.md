# Cannon and rocket presentation

The v0.1.8 effects run on successful production weapon fire and the existing swept-projectile impact callback. The shot direction, inherited vehicle speed, collision exclusion list, hit energy, damage radius and saved destruction are unchanged. The presentation does not apply an extra damage event.

A tank shot has a short forward muzzle discharge, a small recoil of the barrel's visible meshes and its own spatial report. At impact, broken fire tongues and a brief local light lead an expanding surface-aligned pressure/dust ring. Sparks and tumbling chips leave the centre, with rising smoke lingering after the fire ends. The centre is not covered by an opaque sphere. The supplied original generated smoke sprite is converted to luminance in the shader, given varying rotation/scale and small procedural distortion, and faded; its source record is `game/assets/fx/sources.json`. No photograph, third-party sound recording or explosion footage is packaged.

| Phase | Duration | Presentation |
| --- | ---: | --- |
| Muzzle flame | 0.16 s | Directional warm/white fire cards at the real muzzle |
| Visual recoil | 0.46 s | Up to 0.30 m, fast compression and slower return |
| Muzzle smoke | 1.4 s | Small spreading and fading puffs |
| Impact fire/light | 0.38 / 0.26 s | Fragmented emission, no opaque core or shadow map |
| Pressure pulse | 0.55 s | Broken translucent annulus normal to the actual hit surface |
| Dust | 2.15 s | Low peripheral puffs, centre kept open |
| Impact smoke/debris | 3.4 s | Fading smoke and cosmetic chips; world destruction is separate |

Twelve impact slots and eight discharge slots are created during setup, with twenty spatial audio players. Each impact has 108 bounded particle instances, submitted with MultiMeshes; there are no particle rigid bodies. Old effect slots can be reused. The existing 32-projectile pool retains its refusal policy when full. Sixteen transient recoil records restore their mesh origins on expiry, reuse, eviction or clear. Switching away does not leave a barrel compressed. All shadows remain disabled for effect lights; light energy and per-particle values change during playback, not shader source or shader feature flags. Hidden fire and spark stages stop their per-instance updates.

Recoil changes only each vehicle's independent, directly parented barrel mesh nodes. It never moves the chamber pivot, muzzle marker, collider, shared Mesh resource, saved turret yaw or barrel pitch. The current model merges the small cannon breech and barrel by material, so the breech detail moves with the barrel. This is a modest visual approximation, not a simulation of a real recoil mechanism.

`weapon_audio.gd` generates and caches original 24 kHz mono 16-bit PCM for cannon report, rocket launch and impact. Each combines a short broadband transient, low-frequency pressure/rumble and a decaying reflection/fracture tail. Soft saturation bounds sample amplitude. `AudioStreamPlayer3D` supplies positional attenuation (32 m unit size, 650 m maximum distance) on the existing Master bus. Listening quality, clipping when many sounds overlap and first-use rendering cost require native verification; the source tests do not make an FPS or listening-quality claim.

## Verification and recording contract

Small headless fixtures passed: 33 presentation/pool/recoil/PCM checks, 49 existing real Jolt weapon/sweep/damage/repair/save checks, and 18 combat-vehicle state checks. Reports and logs are in `reports/combat-effects-v018/`; the weapon report remains `reports/combat-weapons/headless.json`. This run does not load the full city or read/write user saves.

Godot's Dummy RenderingServer returns default values from MultiMesh transform/color getters. The dedicated fixture therefore observes the actual production particle submission boundary, instead of treating dummy getters as GPU evidence. It checks finite values, bounded opacity, phase order, pool/resource identity and clear/reuse. Native shader compilation, texture appearance, transparency and audible impact remain separate acceptance work.

The existing `effects._slots`, `_cursor`, `CAPACITY`, `slot.node` and `slot.age` interfaces remain available to the real gameplay validator. `impact_effect(point, size, normal)` adds an optional hit normal and stays presentation-only. `effects.emit_muzzle(point, direction, kind)` is called by accepted weapon fire. `weapon_audio.stream(kind)` exposes the exact PCM stream actually used in game. Capture successful real shots and their hit callbacks; useful impact ages are approximately 0.08 s (fire and fragments), 0.65 s (dust and exposed destruction), and 1.1 s (lingering smoke). These are stage selections, not substitute explosions composited into footage.

The implementation follows Godot's [spatial shader built-ins and render modes](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html), [MultiMesh instance data](https://docs.godotengine.org/en/stable/classes/class_multimesh.html), and [AudioStreamPlayer3D attenuation](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html). Particle animation uses simulation age rather than shader `TIME`, so pausing the game freezes the visuals along with projectiles.
