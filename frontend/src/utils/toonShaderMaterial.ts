import * as THREE from 'three';

// Vertex Shader avec support shadows et environment map
const toonVertexShader = `
  #include <common>
  #include <shadowmap_pars_vertex>

  varying vec3 vNormal;
  varying vec3 vViewDir;
  varying vec3 vWorldPos;

  void main() {
    #include <beginnormal_vertex>
    #include <defaultnormal_vertex>
    #include <begin_vertex>
    #include <worldpos_vertex>
    #include <shadowmap_vertex>

    vec4 modelPosition = modelMatrix * vec4(position, 1.0);
    vec4 viewPosition = viewMatrix * modelPosition;
    vec4 clipPosition = projectionMatrix * viewPosition;

    vNormal = normalize(normalMatrix * normal);
    vViewDir = normalize(-viewPosition.xyz);
    vWorldPos = modelPosition.xyz;

    gl_Position = clipPosition;
  }
`;

// Fragment Shader avec environment map
const toonFragmentShader = `
  #include <common>
  #include <packing>
  #include <lights_pars_begin>
  #include <shadowmap_pars_fragment>
  #include <shadowmask_pars_fragment>

  uniform vec3 uColor;
  uniform float uGlossiness;
  uniform samplerCube uEnvMap;
  uniform float uEnvMapIntensity;
  uniform vec3 uRimColor;
  uniform float uRimWidth;

  varying vec3 vNormal;
  varying vec3 vViewDir;
  varying vec3 vWorldPos;

  void main() {
    // Shadow calculation
    float shadow = 1.0;
    #ifdef USE_SHADOWMAP
      DirectionalLightShadow directionalLight = directionalLightShadows[0];
      shadow = getShadow(
        directionalShadowMap[0],
        directionalLight.shadowMapSize,
        directionalLight.shadowBias,
        directionalLight.shadowRadius,
        vDirectionalShadowCoord[0]
      );
    #endif

    // Directional light - cel shading
    float NdotL = dot(vNormal, directionalLights[0].direction);
    float lightIntensity = smoothstep(0.0, 0.01, NdotL * shadow);
    vec3 light = directionalLights[0].color * lightIntensity;

    // Specular highlight - quantized
    vec3 halfVector = normalize(directionalLights[0].direction + vViewDir);
    float NdotH = dot(vNormal, halfVector);
    float specularIntensity = pow(max(NdotH * lightIntensity, 0.0), uGlossiness * uGlossiness);
    float specularIntensitySmooth = smoothstep(0.05, 0.1, specularIntensity);
    vec3 specular = specularIntensitySmooth * directionalLights[0].color;

    // Rim lighting
    float rimDot = 1.0 - dot(vViewDir, vNormal);
    float rimThreshold = 0.2;
    float rimIntensity = rimDot * pow(max(NdotL, 0.0), rimThreshold);
    rimIntensity = smoothstep(uRimWidth - 0.01, uRimWidth + 0.01, rimIntensity);
    vec3 rim = rimIntensity * uRimColor;

    // Environment map reflection
    vec3 reflectDir = reflect(-vViewDir, vNormal);
    vec3 envColor = textureCube(uEnvMap, reflectDir).rgb;
    vec3 envReflection = envColor * uEnvMapIntensity * lightIntensity;

    // Combine all components
    vec3 finalColor = uColor * (ambientLightColor + light + specular + rim + envReflection);

    gl_FragColor = vec4(finalColor, 1.0);
  }
`;

export interface ToonShaderParams {
  color?: THREE.Color | string | number;
  glossiness?: number;
  rimColor?: THREE.Color | string;
  rimWidth?: number;
  envMapIntensity?: number;
}

export function createToonMaterial(params: ToonShaderParams = {}): THREE.ShaderMaterial {
  const {
    color = 0xffffff,
    glossiness = 32,
    rimColor = new THREE.Color(1, 1, 1),
    rimWidth = 0.6,
    envMapIntensity = 0.5,
  } = params;

  return new THREE.ShaderMaterial({
    vertexShader: toonVertexShader,
    fragmentShader: toonFragmentShader,
    uniforms: {
      uColor: { value: new THREE.Color(color) },
      uGlossiness: { value: glossiness },
      uRimColor: { value: new THREE.Color(rimColor) },
      uRimWidth: { value: rimWidth },
      uEnvMap: { value: null },
      uEnvMapIntensity: { value: envMapIntensity },
      ...THREE.UniformsLib.lights,
      ...THREE.UniformsLib.shadowmap,
    },
    lights: true,
    shadowMap: {
      type: THREE.PCFShadowMapType,
    },
    side: THREE.FrontSide,
  });
}

export function applyToonShaderToAvatar(
  model: THREE.Group | THREE.Object3D,
  envMap: THREE.Texture | null,
  params: ToonShaderParams = {}
): void {
  model.traverse((node) => {
    if (node instanceof THREE.Mesh) {
      const material = createToonMaterial(params);

      if (envMap) {
        (material.uniforms.uEnvMap as any).value = envMap;
      }

      // Enable shadow casting/receiving
      node.castShadow = true;
      node.receiveShadow = true;

      node.material = material;
    }
  });
}
