shader_type canvas_item;

uniform float iTime;
uniform vec3 iCameraPosition = vec3(0, 0, -1);
uniform vec3 iCameraLookAt = vec3(0, 0, 0);

float sdSphere(vec3 p, float r)
{
	return length(p) - r;
}

float sdf(vec3 pos)
{
	float t = sdSphere(pos - vec3(0.0, 0.0, 10.0), 3.0);

	return t;
}

float march(vec3 origin, vec3 direction)
{
	float t = 0.0;

	for (int i = 0; i < 64; i++)
	{
		float res = sdf(origin + direction * t);
		if (res < (0.0001 * t))
		{
			return t;
		}
		t += res;
	}

	return -1.0;
}

vec3 getNormal(vec3 pos)
{
	float c = sdf(pos);
	vec2 epsZero = vec2(0.001, 0.0);
	return normalize(vec3(sdf(pos + epsZero.xyy), sdf(pos + epsZero.yxy), sdf(pos + epsZero.yyx)) - c);
}

vec3 render(vec3 rayOrigin, vec3 rayDirection)
{
	vec3 color = vec3(1, 1, 1);
	float t = march(rayOrigin, rayDirection);

	vec3 L = normalize(vec3(sin(iTime)*1.0, cos(iTime*0.5)+0.5, -0.5));

	if (t > -1.0)
	{
		vec3 pos = rayOrigin + rayDirection * t;
		vec3 N = getNormal(pos);

		vec3 objectSurfaceColour = vec3(0.4, 0.8, 0.1);
		// L is vector from surface point to light, N is surface normal. N and L must be normalized!
		float NoL = max(dot(N, L), 0.0);
		vec3 LDirectional = vec3(1.80,1.27,0.99) * NoL;
		vec3 LAmbient = vec3(0.03, 0.04, 0.1);
		vec3 diffuse = objectSurfaceColour * (LDirectional + LAmbient);

		color = diffuse;

		float shadow = 0.0;
		vec3 shadowRayOrigin = pos + N * 0.01;
		vec3 shadowRayDir = L;
		t = march(shadowRayOrigin, shadowRayDir);
		if (t >= -1.0)
		{
			shadow = 1.0;
		}
		color = mix(color, color*0.8, shadow);
	}

	return color;
}

vec2 normalizeScreenCoords(vec2 resolution, vec2 fragCoord)
{
	vec2 result = 2.0 * (fragCoord / resolution.xy - 0.5);
	result.x *= resolution.x / resolution.y;
	return result;
}

vec3 getCameraRayDirection(vec2 uv)
{
	vec3 forward = normalize(iCameraLookAt - iCameraPosition);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	vec3 up = normalize(cross(forward, right));
	return normalize(uv.x * right + uv.y * up + forward * 2.0);
}

void fragment()
{
	vec2 uv = normalizeScreenCoords(1.0 / SCREEN_PIXEL_SIZE, FRAGCOORD.xy);
	vec3 rayDirection = getCameraRayDirection(uv);
	vec3 col = render(iCameraPosition, rayDirection);
	COLOR = vec4(col, 1);
}
