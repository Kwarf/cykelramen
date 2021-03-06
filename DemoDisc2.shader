shader_type canvas_item;

uniform float iTime;
uniform vec3 iCameraPosition;
uniform vec3 iCameraLookAt;
uniform vec3 iBallPosition;
uniform sampler2D iPrecalcTexture;

const float PRECALC_TIME = (1.0 / 60.0) * 256.0;
const float BPM = 175.0;
const float PI = 3.14159;

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

float pModPolar(inout vec2 p, float repetitions) {
	float angle = 2.0*PI/repetitions;
	float a = atan(p.y, p.x) + angle/2.;
	float r = length(p);
	float c = floor(a/angle);
	a = mod(a,angle) - angle/2.;
	p = vec2(cos(a), sin(a))*r;
	if (abs(c) >= (repetitions/2.0)) c = abs(c);
	return c;
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

vec4 opMinColoredSmooth(vec4 a, vec4 b, float s)
{
	float i = clamp(0.5 + 0.5 * (b.w - a.w) / s, 0.0, 1.0);
	return vec4(mix(b.rgb, a.rgb, i), mix(b.w, a.w, i) - s * i * (1.0 - i));
}

vec3 opRep(vec3 p, vec3 c)
{
	return mod(p+0.5*c,c)-0.5*c;
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

float sdSphere(vec3 p, float s)
{
	return length(p)-s;
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
	// Seat tube
	vec3 p = pos;
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

	// Whatever the wheel holding thingies (wht???) are called
	t = fOpUnionRound(t, sdSubFrame(pos), 0.01);

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

vec4 vocalScene(vec3 pos)
{
	float punch = punch(iTime);
	float beat = beat(iTime);
	float spin = beat * 45.0 - 114.0;
	vec4 obj = vec4(vec3(0.05), sdCylinder(pos+vec3(0.0, 0.0, 0.5), vec2(0.5+punch*0.1, 0.025))-0.025);

	vec3 p = pos - vec3(0.0, 0.05, -0.5);
	pR(p.xz, radians(spin));
	p.x += 0.3;
	pR(p.xy, radians(-13));
	obj = opMinColored(obj, vec4(rgb(42, 183, 227), sdBikeFrame(p / 1.5) * 1.5));

	if (beat > 152.0)
	{
		p = pos;
		if (beat > 154.0)
		{
			p.x = abs(p.x);
		}
		p -= vec3(1.2, 0.0, 0.7);
		pR(p.xz, radians(spin));
		obj = opMinColored(obj, vec4(vec3(0.05), sdCylinder(p, vec2(0.5+punch*0.1, 0.025))-0.025));
		p.y -= 0.05;
		float bs = 0.7 + punch * 0.1;
		obj = opMinColored(obj, vec4(vec3(0.9), sdBowl(p / bs) * bs));
		pR(p.yz, radians(-30));
		p -= vec3(0.0, 0.2, 0.4);
		float chopz = sdChopsticks(p / bs) * bs;
		p -= vec3(0.1, 0.03, 0.0);
		pR(p.yz, radians(2.3));
		pR(p.xz, radians(-15));
		chopz = min(chopz, sdChopsticks(p / bs) * bs);
		obj = opMinColored(obj, vec4(rgb(205,133,63), chopz));
	}

	obj = opMinColored(obj, sdTableMat(pos + vec3(0.0, 0.1, 0.0)));

	return obj;
}

vec4 morphScene(vec3 pos)
{
	float punch = punch(iTime);
	float beat = beat(iTime);
	vec3 p = pos;
	p += vec3(0.0, 0.0, 0.0);
	pModPolar(p.xz, 3);
	p -= vec3(1.0, 0.0, 0.0);
	pR(p.xz, radians(90));
	p += vec3(0.0, -0.1, -0.35+punch*0.2);
	const float k = 0.7;
    float c = cos(k*p.x);
    float s = sin(k*p.x);
    mat2  m = mat2(vec2(c,-s),vec2(s,c));
    vec3  q = vec3(m*p.xy,p.z);
	pR(q.yz, radians(-25));
	pR(q.xy, radians(10));
	vec4 obj = vec4(rgb(255, 16, 32), sdBikeFrame(q));

	if (beat > 168.0)
	{
		obj = opMinColoredSmooth(obj, vec4(vec3(0.9), sdBowl(pos)), 0.1);
	}
	if (beat > 170.0)
	{
		p = pos;
		pR(p.yz, radians(-30));
		p -= vec3(0.0, 0.27, 0.6);
		float chopz = sdChopsticks(p / 1.3) * 1.3;
		p -= vec3(0.1, 0.03, 0.0);
		pR(p.yz, radians(2.3));
		pR(p.xz, radians(-15));
		chopz = min(chopz, sdChopsticks(p / 1.3) * 1.3);
		obj = opMinColored(obj, vec4(rgb(205,133,63), chopz));
	}

	obj = opMinColored(obj, sdTableMat(pos));

	if (beat > 192.0)
	{
		p = pos - vec3(0.01, 0.69, -1.0);
		float fbs = 0.07;
		obj = opMinColored(obj, vec4(vec3(0.05), sdBikeFrame(p / fbs) * fbs));
	}

	return obj;
}

vec4 scene(vec3 pos)
{
	if (beat(iTime) >= 160.0)
	{
		return morphScene(pos);
	}

	return vocalScene(pos);
}

vec4 march(vec3 origin, vec3 direction)
{
	float t = 0.0;

	for (int i = 0; i < 64; i++)
	{
		vec4 res = scene(origin + direction * t);
		if (res.w < (0.0005 * t))
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
		float kack = 0.8 - abs(rayDirection.y * 0.3 - 0.14) * 1.5;
		color = vec3(kack, kack, 1.0);
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
	if (iTime < 49.37)
	{
		discard;
	}
	else
	{
		vec2 uv = normalizeScreenCoords(1.0 / SCREEN_PIXEL_SIZE, FRAGCOORD.xy);
		vec3 rayDirection = getCameraRayDirection(uv);
		vec3 col = render(iCameraPosition, rayDirection);
		COLOR = vec4(pow(col, vec3(0.4545)), 1);
	}
}
