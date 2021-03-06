#version 430 core

#ifdef _COMPUTE_

// compute shader which populates the light grid and light index lists, then does the lighting computation

// tiles are 32x32 pixels
#define TILE_SIZE 32
layout(local_size_x = TILE_SIZE, local_size_y = TILE_SIZE) in;

//uniform layout(binding = 0) sampler2D ambient_map;
//uniform layout(binding = 1) sampler2D diffuse_map;
//uniform layout(binding = 2) sampler2D specular_map;
//uniform layout(binding = 3) sampler2D normal_map;
//uniform layout(binding = 4) sampler2D depth_map;
uniform layout(binding = 2, rgba32f) coherent restrict readonly image2D ambient_map;
uniform layout(binding = 3, rgba32f) coherent restrict readonly image2D diffuse_map;
uniform layout(binding = 4, rgba32f) coherent restrict readonly image2D specular_map;
uniform layout(binding = 5, rgba32f) coherent restrict readonly image2D normal_map;
uniform layout(binding = 6, rgba32f) coherent restrict readonly image2D depth_map;

uniform layout(binding = 0, rgba32f) coherent restrict writeonly image2D out_Image;
uniform layout(binding = 1, rgba32f) coherent restrict writeonly image2D out_Depth;

//uniform layout(binding = 5) samplerBuffer lights_buffer;
uniform layout(binding = 7, r32f) restrict readonly imageBuffer lights_buffer; // NOTE: coherent was causing performance problems, but we don't need it since this is read only
uniform layout(location = 5) uint num_lights;
// light struct is 7 bytes
#define LIGHT_SIZE 7

shared int numLightsForTile;
shared int lightsForTile[1024];

uniform layout(location = 6) vec3 light_Position;
uniform layout(location = 7) vec3 light_Power;
uniform layout(location = 8) float light_Size;

uniform layout(location = 3) mat4 camMvMatrix;
uniform layout(location = 4) mat4 camPjMatrix;

void main()
{
    const ivec2 tile_id = ivec2(gl_WorkGroupID);
    const ivec2 thread_id = ivec2(gl_LocalInvocationID);
    const ivec2 i_Tex = ivec2(gl_GlobalInvocationID); // coordinates for indexing into output images
//    const ivec2 imageSize = textureSize(depth_map, 0);
    const ivec2 imageSize = imageSize(depth_map);

    // bounds of this tile
    const ivec2 tile_min = ivec2(tile_id.x * TILE_SIZE, tile_id.y * TILE_SIZE);
    const ivec2 tile_max = tile_min + ivec2(TILE_SIZE, TILE_SIZE);
    // need to init shared counter (better way to do this? atomics?)
    numLightsForTile = 0;
    memoryBarrierShared();

    // first, we need to populate the list of lights that affect the current tile
    // use the thread index to iterate through the light list
    const int lightIdx = thread_id.y * TILE_SIZE + thread_id.x;
    if (lightIdx < num_lights) {
        bool addLight = true;
        // we need to consider this light for the tile
//        float lightx = texelFetch(lights_buffer, lightIdx*LIGHT_SIZE).r;
//        float lighty = texelFetch(lights_buffer, lightIdx*LIGHT_SIZE+1).r;
//        float lightz = texelFetch(lights_buffer, lightIdx*LIGHT_SIZE+2).r;
//        float lightSize = texelFetch(lights_buffer, lightIdx*LIGHT_SIZE+6).r;
        float lightx = imageLoad(lights_buffer, lightIdx*LIGHT_SIZE).r;
        float lighty = imageLoad(lights_buffer, lightIdx*LIGHT_SIZE+1).r;
        float lightz = imageLoad(lights_buffer, lightIdx*LIGHT_SIZE+2).r;
        float lightSize = imageLoad(lights_buffer, lightIdx*LIGHT_SIZE+6).r;

        // do some sort of sphere/AABB screen space bounds calculation
        // variance matrix (identity matrix for a unit sphere) to transform from parameter space to object space
        mat4 varMatrix = mat4( vec4(lightSize, 0, 0, 0),
                               vec4(0, lightSize, 0, 0),
                               vec4(0, 0, lightSize, 0),
                               vec4(lightx, lighty, lightz, 1.0));
        mat4 transform = camPjMatrix * camMvMatrix * varMatrix;
        mat4 transformRows = transpose(transform);
        // formula from http://web4.cs.ucl.ac.uk/staff/t.weyrich/projects/quadrics/pbg06.pdf
        // NOTE: this is currently not working, but the most promising way to do the calculation with just matrices
        float a = dot(transformRows[3].xyz, transformRows[3].xyz) - (transformRows[3].w*transformRows[3].w);
        float b = -2 * (dot(transformRows[0].xyz, transformRows[3].xyz) - (transformRows[0].w*transformRows[3].w));
        float c = dot(transformRows[0].xyz, transformRows[0].xyz) - (transformRows[0].w*transformRows[0].w);
        // quadratic formula
        float root1 = (-b + sqrt(b*b - 4*a*c)) / (2*a);
        float root2 = (-b - sqrt(b*b - 4*a*c)) / (2*a);
        // roots should be in clip space, so x,y are between -1 and 1
        // x bounds are min and max of these
        float xmin = ((min(root1, root2) * 0.5) + 0.5) * imageSize.x;
        float xmax = ((max(root1, root2) * 0.5) + 0.5) * imageSize.x;

        // compare to tile bounds
        if (xmax < tile_min.x || xmin > tile_max.x) {
            //imageStore(out_Image, i_Tex, vec4(0, 1.0, 0, 1.0));
            addLight = false;
            //return;
        }
        // otherwise, try again with y
        a = dot(transformRows[3].xyz, transformRows[3].xyz) - (transformRows[3].w*transformRows[3].w);
        b = -2 * (dot(transformRows[1].xyz, transformRows[3].xyz) - (transformRows[1].w*transformRows[3].w));
        c = dot(transformRows[1].xyz, transformRows[1].xyz) - (transformRows[1].w*transformRows[1].w);
        // quadratic formula
        root1 = (-b + sqrt(b*b - 4*a*c)) / (2*a);
        root2 = (-b - sqrt(b*b - 4*a*c)) / (2*a);
        // y bounds
        float ymin = ((min(root1, root2) * 0.5) + 0.5) * imageSize.y;
        float ymax = ((max(root1, root2) * 0.5) + 0.5) * imageSize.y;
        // compare to tile bounds
        if (ymax < tile_min.y || ymin > tile_max.y) {
            //imageStore(out_Image, i_Tex, vec4(0, 0, 1.0, 1.0));
            addLight = false;
            //return;
        }

        if (addLight) {
            int index = atomicAdd(numLightsForTile, 1); // atomic increment the offset counter
            lightsForTile[index] = lightIdx;
        }
    }
    barrier(); // ensures that all threads in the work group have processed their light
    // we should have lightForTile populated with the index of each light which affects the tile

    if (i_Tex.x >= imageSize.x || i_Tex.y >= imageSize.y) {
        // if we go outside the bounds of the image, no need to do the shading calculation
        return;
    }

    // now do the lighting calculation for the fragment
    // currently not SSAA, need to fix (more threads?)
//    vec4 ambient_Color = texelFetch(ambient_map, i_Tex, 0);
//    vec4 diffuse_Color = texelFetch(diffuse_map, i_Tex, 0);
//    vec4 specular_Color = texelFetch(specular_map, i_Tex, 0);
//    vec3 view_Normal = texelFetch(normal_map, i_Tex, 0).xyz;
    vec4 ambient_Color = imageLoad(ambient_map, i_Tex);
    vec4 diffuse_Color = imageLoad(diffuse_map, i_Tex);
    vec4 specular_Color = imageLoad(specular_map, i_Tex);
    vec3 view_Normal = imageLoad(normal_map, i_Tex).xyz;

//    float fragDepth = texelFetch(depth_map, i_Tex, 0).r;
    float fragDepth = imageLoad(depth_map, i_Tex).r;
    vec3 start_Pos = vec3(vec2(i_Tex)/imageSize, fragDepth);
    vec3 ndc_Pos = (2.0 * start_Pos) - 1.0;
    vec4 unproject = inverse(camPjMatrix) * vec4(ndc_Pos, 1.0);
    vec3 viewPos = unproject.xyz / unproject.w;

    vec3 diffuseColor = vec3(0);
    vec3 specularColor = vec3(0);

    // for each light
    for (int i = 0; i < numLightsForTile; i++) {
        // get parameters from buffer
//        float lightx = texelFetch(lights_buffer, lightsForTile[i]*LIGHT_SIZE).r;
//        float lighty = texelFetch(lights_buffer, lightsForTile[i]*LIGHT_SIZE+1).r;
//        float lightz = texelFetch(lights_buffer, lightsForTile[i]*LIGHT_SIZE+2).r;
//        float lightr = texelFetch(lights_buffer, lightsForTile[i]*LIGHT_SIZE+3).r;
//        float lightg = texelFetch(lights_buffer, lightsForTile[i]*LIGHT_SIZE+4).r;
//        float lightb = texelFetch(lights_buffer, lightsForTile[i]*LIGHT_SIZE+5).r;
//        float lightSize = texelFetch(lights_buffer, lightsForTile[i]*LIGHT_SIZE+6).r;

        float lightx = imageLoad(lights_buffer, lightsForTile[i]*LIGHT_SIZE).r;
        float lighty = imageLoad(lights_buffer, lightsForTile[i]*LIGHT_SIZE+1).r;
        float lightz = imageLoad(lights_buffer, lightsForTile[i]*LIGHT_SIZE+2).r;
        float lightr = imageLoad(lights_buffer, lightsForTile[i]*LIGHT_SIZE+3).r;
        float lightg = imageLoad(lights_buffer, lightsForTile[i]*LIGHT_SIZE+4).r;
        float lightb = imageLoad(lights_buffer, lightsForTile[i]*LIGHT_SIZE+5).r;
        float lightSize = imageLoad(lights_buffer, lightsForTile[i]*LIGHT_SIZE+6).r;

        vec3 lightPower = vec3(lightr, lightg, lightb);
        // calculate view space position
        vec4 lightPos = camMvMatrix * vec4(lightx, lighty, lightz, 1.0);

        // do the lighting calculation
        vec3 light_Direction = lightPos.xyz - viewPos;
        float lightDistance = length(light_Direction);

        if (lightDistance > lightSize) {
            continue;
        }

        light_Direction = normalize(light_Direction);
        float distance2 = lightDistance * lightDistance;
        float ndotl = dot(view_Normal, light_Direction);
        float intensity = clamp(ndotl, 0, 1);

        diffuseColor += intensity * lightPower / distance2;

        vec3 halfVector = normalize(light_Direction + vec3(0, 0, -1));
        float ndoth = dot(view_Normal, halfVector);
        float intensity2 = pow(clamp(ndoth, 0, 1), specular_Color.a);

        specularColor += intensity2 * lightPower / distance2;
    }
    vec3 diffuseFinal = diffuseColor * diffuse_Color.rgb;
    vec3 specularFinal = specularColor * specular_Color.rgb;
    vec3 finalFinal = diffuse_Color.rgb * diffuseColor + specularColor.rgb * specularColor;
    imageStore(out_Image, i_Tex, vec4(finalFinal, 1.0));
}

#endif //_COMPUTE_
