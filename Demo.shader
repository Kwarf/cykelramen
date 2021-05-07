shader_type canvas_item;

uniform float iTime;
uniform vec3 iCameraPosition;
uniform vec3 iCameraLookAt;
uniform vec3 iBallPosition;

void pR(inout vec2 p, float a)
{
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float fOpUnionRound(float a, float b, float r)
{
	vec2 u = max(vec2(r - a,r - b), vec2(0));
	return max(r, min (a, b)) - length(u);
}

float opExtrusion(vec3 p, float sdf, float h)
{
	float hh = h / 2.0;
	vec2 w = vec2(sdf, abs(p.z + hh) - hh);
	return min(max(w.x,w.y),0.0) + length(max(w,0.0));
}

float sdPlane(vec3 p, vec3 n, float h)
{
	return dot(p,n) + h;
}

float sdCircle(vec2 p, float r)
{
	return length(p) - r;
}

float sdBox(vec3 p, vec3 b)
{
	vec3 q = abs(p) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdTube(vec3 p, float d, float t, float h)
{
	float r = d / 2.0;
	return opExtrusion(p, abs(sdCircle(p.xy, r)) - t, h);
}

float sdCylinder(vec3 p, vec2 h)
{
	vec2 d = abs(vec2(length(p.xz),p.y)) - h;
	return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdSubFrame(vec3 pos)
{
	// Modeled mirrored
	pos.z = abs(pos.z);

	// Upper
	vec3 p = pos + vec3(-0.20, -0.25, -0.03);
	pR(p.xy, radians(50));
	pR(p.yz, radians(-4));
	float t = sdCylinder(p, vec2(0.006, 0.25));

	// Lower
	p = pos + vec3(-0.21, -0.04, -0.035);
	pR(p.xy, radians(102));
	pR(p.yz, radians(-4));
	t = min(t, sdCylinder(p, vec2(0.006, 0.185)));

	// Bracket
	p = pos + vec3(-0.405, -0.081, -0.05);
	t = fOpUnionRound(t, sdTube(p, 0.025, 0.004, 0.006), 0.006);

	return t;
}

float sdBikeFrame(vec3 pos)
{
	float t = 1e10;
	// Bounding box culling. Worth it? Who knows. Increased FPS from ~420 to ~640 when the frame took up maybe 1/10th of the frame.
	vec3 p = pos + vec3(0.12, -0.24, 0.0);
	if (sdBox(p, vec3(0.55, 0.28, 0.06)) < t)
	{
		// Seat tube
		p = pos;
		pR(p.yz, radians(90));
		p += vec3(0.0, 0.0, 0.02);
		t = sdTube(p, 0.04, 0.003, 0.5);

		// Crank tube
		p = pos + vec3(0.0, 0.0, -0.035);
		t = fOpUnionRound(t, sdTube(p, 0.06, 0.005, 0.07), 0.02);

		// Top tube
		p = pos + vec3(0.32, -0.45, 0.0);
		pR(p.xy, radians(90));
		t = fOpUnionRound(t, sdCylinder(p * vec3(1.3, 1.0, 1.0), vec2(0.02, 0.3)), 0.015);

		// Bottom tube
		p = pos + vec3(0.33, -0.21, 0.0);
		pR(p.xz, radians(90));
		pR(p.yz, radians(58));
		t = fOpUnionRound(t, sdCylinder(p, vec2(0.023, 0.36)), 0.02);

		// Head tube
		p = pos + vec3(0.66, -0.365, 0.0);
		pR(p.yz, radians(90));
		pR(p.xz, radians(8));
		t = fOpUnionRound(t, sdTube(p, 0.05, 0.005, 0.13), 0.015);

		// Whatever the wheel holding thingies (wht™) are called
		t = fOpUnionRound(t, sdSubFrame(pos), 0.01);
	}

	return t;
}

float sdf(vec3 pos)
{
	// Floor plane
	float t = sdPlane(pos, vec3(0.0, 1.0, 0.0), 1.0);

	// Bike
	t = min(t, sdBikeFrame(pos));

	return t;
}

float march(vec3 origin, vec3 direction)
{
	float t = 0.0;

	for (int i = 0; i < 128; i++)
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

	vec3 L = normalize(vec3(sin(iTime)*1.0, cos(iTime*0.5)+2.0, -0.5));

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
