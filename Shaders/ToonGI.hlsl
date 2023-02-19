//
// #ifndef Include_ToonGI
// #define Include_ToonGI
//
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
//
// // Computes the specular term for EnvironmentBRDF
// half3 ToonEnvironmentBRDFSpecular(ToonModelSurfaceData surface_data, half fresnelTerm)
// {
//     float surfaceReduction = 1.0 / (surface_data.roughness2 + 1.0);
//     return half3(surfaceReduction * lerp(surface_data.gi_specular, surface_data.grazingTerm, fresnelTerm).xyz);
// }
//
// float4 GetShadowShiftColor(float2 uv){
//     #if _USE_SHADOWSHIFTMAP
//     return tex2D(_ShadowShiftMap,uv);
//     #else
//     return _ClothShadowColor;
//     #endif
// }
//
// half3 ToonGlossyEnvironmentReflection(half3 reflectVector, float3 positionWS, half perceptualRoughness, half occlusion)
// {
//     #if !defined(_ENVIRONMENTREFLECTIONS_OFF)
//         half3 irradiance;
//
//         #ifdef _REFLECTION_PROBE_BLENDING
//             irradiance = CalculateIrradianceFromReflectionProbes(reflectVector, positionWS, perceptualRoughness);
//         #else
//             #ifdef _REFLECTION_PROBE_BOX_PROJECTION
//             reflectVector = BoxProjectedCubemapDirection(reflectVector, positionWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
//             #endif // _REFLECTION_PROBE_BOX_PROJECTION
//             half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
//             half4 encodedIrradiance = half4(SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip));
//
//             #if defined(UNITY_USE_NATIVE_HDR)
//             irradiance = encodedIrradiance.rgb;
//             #else
//             irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
//             #endif // UNITY_USE_NATIVE_HDR
//         #endif // _REFLECTION_PROBE_BLENDING
//     
//         return irradiance * occlusion;
//     #else
//         // return 0;    
//         return _GlossyEnvironmentColor.rgb * occlusion;
//     #endif // _ENVIRONMENTREFLECTIONS_OFF
// }
//
// half3 ToonEnvironmentBRDF(ToonModelSurfaceData surface_data, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
// {
//     half3 c = indirectDiffuse * surface_data.diffuse;
//     // return indirectDiffuse;
//     c += indirectSpecular * ToonEnvironmentBRDFSpecular(surface_data, fresnelTerm);
//     return c;
// }
//
// half3 ToonGlobalIllumination(ToonModelSurfaceData surface_data, ToonModelLightingData lighting_data,half3 bakedGI)
// {
//     // return bakedGI;
//     half3 reflectVector = reflect(-lighting_data.worldViewDir, lighting_data.worldNormalDir);
//     // return reflectVector;
//     // half NoV = saturate(dot(normalWS, viewDirectionWS));
//     half fresnelTerm = Pow4(1.0 - lighting_data.NdotV);
//
//     half3 indirectDiffuse = bakedGI;
//     // return indirectDiffuse;
//     half3 indirectSpecular = ToonGlossyEnvironmentReflection(reflectVector, lighting_data.positionWS, surface_data.perceptualRoughness, 1.0);
//     
//     half3 color = ToonEnvironmentBRDF(surface_data, indirectDiffuse, indirectSpecular, fresnelTerm);
//     // return color;
//
//     return color * 1.0;
// }
//
// #endif