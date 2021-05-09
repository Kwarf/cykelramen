shader_type canvas_item;

uniform float iTime;
uniform vec3 iCameraPosition;
uniform vec3 iCameraLookAt;
uniform vec3 iBallPosition;
uniform sampler2D iPrecalcTexture;

const float PRECALC_TIME = (1.0 / 60.0) * 256.0;
const float BPM = 175.0;

// Beat sync toys
float beat(float time) { return time / (60.0 / BPM); }
float punch(float time) { float slask; return 1.0 - modf(beat(time), slask); }

vec3 rgb(int r, int g, int b)
{
	return vec3(float(r) / 255.0
		, float(g) / 255.0
		, float(b) / 255.0
	);
}

void pR(inout vec2 p, float a)
{
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float fOpUnionRound(float a, float b, float r)
{
	vec2 u = max(vec2(r - a,r - b), vec2(0));
	return max(r, min (a, b)) - length(u);
}

vec2 opRevolution(vec3 p, float w)
{
	return vec2(length(p.xz) - w, p.y);
}

float opExtrusion(vec3 p, float sdf, float h)
{
	float hh = h / 2.0;
	vec2 w = vec2(sdf, abs(p.z + hh) - hh);
	return min(max(w.x,w.y),0.0) + length(max(w,0.0));
}

vec4 opMinColored(vec4 a, vec4 b)
{
	return a.w < b.w ? a : b;
}

vec3 opRepLim(vec3 p, float c, vec3 l)
{
	return p-c*clamp(round(p/c),-l,l);
}

// 2D primitives

float sdCircle(vec2 p, float r)
{
	return length(p) - r;
}

float sdRoundRect(vec2 p, vec2 b, vec4 r)
{
	r.xy = (p.x>0.0)?r.xy : r.zw;
	r.x  = (p.y>0.0)?r.x  : r.y;
	vec2 q = abs(p)-b+r.x;
	return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}

float sdArc(vec2 p, vec2 sca, vec2 scb, float ra, float rb)
{
	p *= mat2(vec2(sca.x,sca.y),vec2(-sca.y,sca.x));
	p.x = abs(p.x);
	float k = (scb.y*p.x>scb.x*p.y) ? dot(p,scb) : length(p);
	return sqrt( dot(p,p) + ra*ra - 2.0*ra*k ) - rb;
}

// 3D primitives

float sdPlane(vec3 p, vec3 n, float h)
{
	return dot(p,n) + h;
}

float sdBox(vec3 p, vec3 b)
{
	vec3 q = abs(p) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdRoundBox(vec3 p, vec3 b, float r)
{
	vec3 q = abs(p) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

// 3D primitives (custom)

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

// 3D models

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
	pos += vec3(0.0, -0.035, 0.0);
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

float sdBowl(vec3 pos)
{
	vec2 opR = opRevolution(pos + vec3(0.0, -0.74, 0.0), 0.2);
	float ta = 3.14*1.5;
	float tb = 3.14*0.5;
	float t = sdArc(opR, vec2(sin(ta),cos(ta)), vec2(sin(tb),cos(tb)), 0.7, 0.05);
	t = min(t, sdRoundRect(opR+vec2(0.0, 0.7), vec2(0.35, 0.05), vec4(0.0, 0.03, 0.0, 0.03)));
	return max(-sdCircle(opR+vec2(0.0, 2.2), 1.5), t);
}

vec4 sdTableMat(vec3 pos)
{
	vec3 p = pos + vec3(0.0, -0.02, 0.0);
	p = opRepLim(p, 0.05, vec3(35.0, 0.0, 0.0));
	vec4 pins = vec4(rgb(160, 82, 45), sdRoundBox(p, vec3(0.01, 0.01, 1.3), 0.01));

	p = pos + vec3(0.0, -0.03, 0.0);
	p = opRepLim(p, 0.62, vec3(0.0, 0.0, 2.0));
	vec4 ropes = vec4(rgb(245, 222, 179), sdRoundBox(p, vec3(1.77, 0.01, 0.01), 0.01));

	return opMinColored(pins, ropes);
}

float sdChopsticks(vec3 pos)
{
	vec3 p = pos;
	pR(p.yz, radians(90));
	float t = sdCylinder(p, vec2(0.02, 0.8));
	t = fOpUnionRound(t, sdBox(pos - vec3(0.0, 0.0, 0.9), vec3(0.024, 0.024, 0.15)), 0.015);
	return t;
}

vec4 dinerScene(vec3 pos)
{
	// Table
	vec4 obj = vec4(0.2, 0.2, 0.2, sdRoundBox(pos+vec3(0.0, 0.08, 0.0), vec3(10.0, 0.03, 1.4), 0.05));
	obj = opMinColored(obj, vec4(0.2, 0.2, 0.4, sdRoundBox(pos-vec3(0.0, 1.5, 1.5), vec3(10.0, 3.0, 0.03), 0.05)));
	obj = opMinColored(obj, vec4(0.4, 0.2, 0.2, sdRoundBox(pos-vec3(0.0, 2.5, 1.3), vec3(10.0, 0.7, 0.03), 0.05)));
	obj = opMinColored(obj, vec4(0.8, 0.8, 1.0, sdRoundBox(pos-vec3(0.0, 2.5, 0.3), vec3(0.7, 0.6, 1.0), 0.1)));

	// Bikes
	if (iTime > 6.0 && sdBox(pos-vec3(0.0, 0.95, 0.0), vec3(1.0, 0.9, 1.0)) < 1e10) // 111 -> 134 FPS (540p)
	{
		float sampleRow = min((iTime - 6.0) / PRECALC_TIME, 1.0);
		float dBikes = 1e10;
		float precalcWidth = float(textureSize(iPrecalcTexture, 0).x);
		for (int i = 0; i < 5; i++)
		{
			float offs = float(i) * 4.0;
			vec3 bikePosition = texture(iPrecalcTexture, vec2(offs / precalcWidth, sampleRow)).xyz;
			mat3 bikeTranslation = mat3(
				texture(iPrecalcTexture, vec2((offs + 1.0) / precalcWidth, sampleRow)).xyz
				, texture(iPrecalcTexture, vec2((offs + 2.0) / precalcWidth, sampleRow)).xyz
				, texture(iPrecalcTexture, vec2((offs + 3.0) / precalcWidth, sampleRow)).xyz
			);
			dBikes = min(dBikes, sdBikeFrame(bikeTranslation * (pos - bikePosition)));
		}

		// Cut / clip / w/e
		dBikes = max(-sdBox(pos-vec3(0.0, 7.8, 0.3), vec3(2.0, 6.0, 2.0)), dBikes);

		obj = opMinColored(obj, vec4(0.2, 0.9, 0.9, dBikes));
	}

	// Bowl
	float beat = beat(iTime);
	if (beat >= 16.0 && beat < 17.0)
	{
		// Tease the bowl
		float bowl = sdBox(pos - vec3(0.0, 1.0 - punch(iTime), 0.0), vec3(1.0, 0.05, 1.0));
		bowl = max(bowl, sdBowl(pos));
		obj = opMinColored(obj, vec4(0.9, 0.9, 0.9, bowl));
	}
	else if (beat >= 18.0 && beat < 19.0)
	{
		// Whoop the bowl
		float bowl = sdBox(pos - vec3(0.0, 1.5 - punch(iTime), 0.0), vec3(1.0, 0.6, 1.0));
		bowl = max(-bowl, sdBowl(pos));
		obj = opMinColored(obj, vec4(0.9, 0.9, 0.9, bowl));
	}
	else if (beat >= 19.0 && beat < 32.0)
	{
		// Show the bowl
		obj = opMinColored(obj, vec4(0.9, 0.9, 0.9, sdBowl(pos)));
	}
	else if (beat >= 32.0)
	{
		// Boop the bowl
		vec3 p = pos * (1.0 + punch(iTime) * -0.05);
		obj = opMinColored(obj, vec4(0.9, 0.9, 0.9, sdBowl(p)));
	}

	// Chopstick
	if (iTime >= 3.0)
	{
		if (iTime < 4.0)
		{
			// Cutty stick
			vec3 p = pos;
			p -= vec3(1.2, 0.08, (iTime - 3.0) * -2.2);
			float chopz = sdChopsticks(pos - vec3(1.2, 0.08, -0.2));
			chopz = min(chopz, sdChopsticks(pos - vec3(1.249, 0.08, -0.2)));
			chopz = max(-sdBox(p, vec3(0.1, 0.1, 1.1)), chopz);
			obj = opMinColored(obj, vec4(rgb(205,133,63), chopz));
		}
		else
		{
			float chopz = sdChopsticks(pos - vec3(1.2, 0.08, -0.2));
			chopz = min(chopz, sdChopsticks(pos - vec3(1.249, 0.08, -0.2)));
			obj = opMinColored(obj, vec4(rgb(205,133,63), chopz));
		}
	}

	if (iTime > 2.0 && iTime < 3.0)
	{
		// Cutty cube for matty dude fade in thingy
		vec3 p = pos;
		pR(p.xz, radians(45));
		p += vec3(0.0, 0.0, (iTime - 2.0) * 6.0);
		vec4 mat = sdTableMat(pos);
		mat.w = max(-sdBox(p, vec3(3.0, 0.5, 3.0)), mat.w);
		obj = opMinColored(obj, mat);
	}
	else if (iTime >= 3.0)
	{
		// No more fadey, is there now
		obj = opMinColored(obj, sdTableMat(pos));
	}

	// Table mat
	return obj;
}

vec4 bikeScene(vec3 pos)
{
	float bg = sdBox(pos, vec3(10.0, 0.1, 10.0));
	bg = min(bg, sdBox(pos-vec3(0.0, 0.0, 5.0), vec3(10.0, 10.0, 1.0)));
	vec4 obj = vec4(0.05, 0.05, 0.05, bg);

	vec3 p = pos - vec3(-2.5, 0.5, 0.0);
	pR(p.xz, cos(iTime)*2.3);
	pR(p.xy, sin(iTime)*1.8);
	obj = opMinColored(obj, vec4(1.0, 0.0, 0.0, sdBikeFrame(p)));
	p = pos - vec3(0.0, 0.6, 0.0);
	pR(p.xz, sin(iTime)*3.6);
	pR(p.xy, cos(iTime)*1.2);
	obj = opMinColored(obj, vec4(0.0, 1.0, 0.0, sdBikeFrame(p)));
	p = pos - vec3(2.5, 0.5, 0.0);
	pR(p.xz, -sin(iTime)*2.7);
	pR(p.xy, -cos(iTime)*1.5);
	obj = opMinColored(obj, vec4(0.0, 0.0, 2.0, sdBikeFrame(p)));

	return obj;
}

vec4 scene(vec3 pos)
{
	float beat = beat(iTime);
	if (beat >= 48.0)
	{
		return bikeScene(pos);
	}

	return dinerScene(pos);
}

vec4 march(vec3 origin, vec3 direction)
{
	float t = 0.0;

	for (int i = 0; i < 128; i++)
	{
		vec4 res = scene(origin + direction * t);
		if (res.w < (0.0001 * t))
		{
			return vec4(res.rgb, t);
		}
		t += res.w;
	}

	return vec4(-1.0);
}

vec3 getNormal(vec3 pos)
{
	float c = scene(pos).w;
	vec2 epsZero = vec2(0.001, 0.0);
	return normalize(vec3(scene(pos + epsZero.xyy).w, scene(pos + epsZero.yxy).w, scene(pos + epsZero.yyx).w) - c);
}

vec3 render(vec3 rayOrigin, vec3 rayDirection)
{
	vec3 color = vec3(1, 1, 1);
	vec4 t = march(rayOrigin, rayDirection);

	vec3 L = normalize(iBallPosition);

	if (t.w == -1.0)
	{
		// Miss color
		color = vec3(0.9, 0.9, 1.0);
	}
	else
	{
		vec3 pos = rayOrigin + rayDirection * t.w;
		vec3 N = getNormal(pos);

		float NoL = max(dot(N, L), 0.0);
		vec3 LDirectional = vec3(1.0,1.0,1.0) * NoL;
		vec3 LAmbient = vec3(0.1,0.1,0.1);
		color = t.rgb * (LDirectional + LAmbient);

		float shadow = 0.0;
		vec3 shadowRayOrigin = pos + N * 0.01;
		vec3 shadowRayDir = L;
		if (march(shadowRayOrigin, shadowRayDir).w > -1.0)
		{
			shadow = 1.0;
		}
		color = mix(color, color*0.3, shadow);
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
	COLOR = vec4(pow(col, vec3(0.4545)), 1);
}
