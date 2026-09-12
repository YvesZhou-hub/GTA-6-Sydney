shader_type sky;

uniform sampler2D panorama : filter_linear_mipmap, repeat_enable;
uniform sampler2D sunset_panorama : filter_linear_mipmap, repeat_enable;
uniform sampler2D night_panorama : filter_linear_mipmap, repeat_enable;
uniform float peak_radiance = 24.0;
uniform bool cycle_enabled = false;
uniform vec3 sun_direction = vec3(0.0,1.0,0.0);
uniform float sun_elevation = 35.0;
uniform float day_weight = 1.0;
uniform float night_weight = 0.0;
uniform vec3 sunset_tint = vec3(1.24,0.84,0.66);
uniform float sunset_gain = 0.85;
uniform float night_gain = 0.07;
uniform float twilight_radiance_limit = 0.65;
uniform vec3 night_airglow = vec3(0.028,0.046,0.075);

vec3 capped(vec3 value, float maximum) {
    float peak=max(value.r,max(value.g,value.b));
    return value*min(1.0,maximum/max(peak,0.0001));
}

vec3 source_without_solar_core(sampler2D source, vec2 uv, vec2 solar_uv) {
    vec3 value=max(textureLod(source,uv,0.0).rgb,vec3(0.0));
    float dx=fract(uv.x-solar_uv.x+0.5)-0.5;
    float radius=length(vec2(dx/0.105,(uv.y-solar_uv.y)/0.16));
    // Remove the photograph's fixed solar disc while retaining its cloud detail.
    // The astronomical disc below is shared by visible sky and reflection cube.
    if (radius<1.0) {
        // A narrow neighbour sample still contains the photographed solar halo
        // and leaves a grey disc inside a bright ring. Interpolate unaffected
        // sky at the SAME altitude over a wide, feathered region instead.
        vec3 left=textureLod(source,vec2(fract(solar_uv.x-0.12),uv.y),0.0).rgb;
        vec3 right=textureLod(source,vec2(fract(solar_uv.x+0.12),uv.y),0.0).rgb;
        vec3 surround=mix(left,right,clamp(dx/0.24+0.5,0.0,1.0));
        value=mix(surround,value,smoothstep(0.22,1.0,radius));
    }
    return capped(value,4.0);
}

void sky() {
    vec2 uv=vec2(atan(EYEDIR.x,-EYEDIR.z)/TAU+0.5,acos(clamp(EYEDIR.y,-1.0,1.0))/PI);
    vec3 radiance=max(textureLod(panorama,uv,0.0).rgb,vec3(0.0));
    if (!cycle_enabled) {
        COLOR=capped(radiance,peak_radiance);
    } else {
        float sun_u=atan(sun_direction.x,-sun_direction.z)/TAU+0.5;
        vec2 day_uv=vec2(fract(uv.x+1222.5/2048.0-sun_u),uv.y);
        vec2 dusk_uv=vec2(fract(uv.x+1228.5/2048.0-sun_u),uv.y);
        vec3 day=source_without_solar_core(panorama,day_uv,vec2(1222.5/2048.0,350.5/1024.0));
        vec3 dusk=source_without_solar_core(sunset_panorama,dusk_uv,vec2(1228.5/2048.0,477.5/1024.0));
        float horizon=exp(-max(EYEDIR.y,0.0)*3.8);
        float facing=pow(max(dot(normalize(vec3(EYEDIR.x,0.001,EYEDIR.z)),normalize(vec3(sun_direction.x,0.001,sun_direction.z))),0.0),3.0);
        // Compress HDR cloud luminance before artistic grading. A whole bright
        // hemisphere must not enter the ACES shoulder or trigger broad glow.
        float dusk_luma=max(dot(dusk,vec3(0.2126,0.7152,0.0722)),0.0001);
        float cloud=1.0-smoothstep(0.06,0.35,(dusk.b-dusk.r)/dusk_luma);
        dusk*=0.72/(1.0+dusk_luma/twilight_radiance_limit);
        float warm_region=horizon*(0.12+0.88*facing);
        vec3 local_tint=mix(vec3(0.72,0.86,1.06),sunset_tint,warm_region*(0.25+0.75*cloud));
        vec3 horizon_warm=vec3(0.15,0.045,0.012)*warm_region;
        dusk=(dusk*local_tint+horizon_warm)*sunset_gain;
        // City-sky fill is part of the same sky/radiance source, not emissive
        // water or an invented moon. Its modest floor preserves night silhouettes.
        vec3 night=capped(max(textureLod(night_panorama,uv,0.0).rgb,vec3(0.0))*night_gain,3.0);
        night*=vec3(0.58,0.72,1.0);
        night+=night_airglow*(0.65+0.35*exp(-abs(EYEDIR.y)*3.0));
        radiance=mix(dusk,day,day_weight);
        radiance=mix(radiance,night,night_weight);
        float solar_visibility=smoothstep(-0.833,0.2,sun_elevation)*(1.0-night_weight);
        float solar_disc=smoothstep(cos(0.006),cos(0.0042),dot(EYEDIR,normalize(sun_direction)))*solar_visibility;
        vec3 solar_color=mix(vec3(1.0,0.40,0.13),vec3(1.0,0.93,0.78),smoothstep(0.0,25.0,sun_elevation));
        radiance+=solar_color*solar_disc*18.0;
        COLOR=capped(radiance,peak_radiance);
    }
}
