shader_type canvas_item;

uniform float iTime;
uniform vec3 iCameraPosition;
uniform vec3 iCameraLookAt;
uniform vec3 iBallPosition;
uniform sampler2D iPrecalcTexture;
uniform int iIterations;

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

vec3 bikeColor(int idx)
{
	if (idx < 1) { return rgb(33, 194, 28); }
	if (idx < 2) { return rgb(42, 183, 227); }
	if (idx < 3) { return rgb(255, 235, 89); }
	if (idx < 4) { return rgb(254,42,124); }
	return rgb(255, 16, 32);
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

	// Whatever the wheel holding thingies (wht™) are called
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

vec4 sdTinyMat(vec3 pos)
{
	pos -= vec3(0.0, 0.165, 0.0);
	vec3 p = pos + vec3(0.0, -0.02, 0.0);
	p = opRepLim(p, 0.05, vec3(17.0, 0.0, 0.0));
	vec4 pins = vec4(rgb(160, 82, 45), sdRoundBox(p, vec3(0.01, 0.01, 0.88), 0.01));

	p = pos + vec3(0.0, -0.03, 0.0);
	p = opRepLim(p, 0.8, vec3(0.0, 0.0, 1.0));
	vec4 ropes = vec4(rgb(245, 222, 179), sdRoundBox(p, vec3(0.88, 0.01, 0.01), 0.01));

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

vec4 showcase(vec3 pos)
{
	vec4 obj = sdTinyMat(pos);

	vec3 p = pos - vec3(0.375, 0.5, -0.1);
	pR(p.xy, radians(12));
	pR(p.xz, radians(45));
	pR(p.yz, radians(35));
	pR(p.xz, radians(-45));
	obj = opMinColored(obj, vec4(bikeColor(1), sdBikeFrame(p)));

	p = pos - vec3(0.0, 0.46, 0.0);
	pR(p.xy, radians(-12));
	pR(p.yz, radians(65));
	p.x += 0.02;
	obj = opMinColored(obj, vec4(bikeColor(4), sdBikeFrame(p)));

	p = pos - vec3(0.2, 0.2 + 0.02, -0.5);
	pR(p.xz, radians(-60));
	float chopz = sdChopsticks(p);
	p -= vec3(0.1, 0.03, 0.0);
	pR(p.yz, radians(2.3));
	pR(p.xz, radians(-15));
	chopz = min(chopz, sdChopsticks(p));
	obj = opMinColored(obj, vec4(rgb(205,133,63), chopz));

	p = pos - vec3(0.0, 0.2, 0.0);
	obj = opMinColored(obj, vec4(0.9, 0.9, 0.9, sdBowl(p / 0.6) * 0.6));

	return obj;
}

vec3 pit(vec3 p, float time) // PositionInTunnel™
{
	float glopper = (time - 17.0) * 2.0;
	pR(p.xy, cos(p.z*0.01) * 4.5);
	pR(p.xy, cos(p.z*0.2) * 0.4);
	pR(p.yz, cos(p.z*0.002) * 0.01);
	p.x += cos(glopper+p.z*0.1) * 3.0;
	p.y += cos(glopper+p.z*0.05) * 2.0;
	return p;
}

float sdTunnel(vec3 pos)
{
	vec3 p = pit(pos - vec3(0.0, 0.0, (iTime - 16.45) * -25.0), iTime);

	// Revolve
	pModPolar(p.xy, 7);
	p -= vec3(7.0, 0.0, 0.0);
	pR(p.xy, radians(90));

	// Repeat
	p = opRep(p, vec3(0.0, 0.0, 1.6));

	float t = sdBox(p, vec3(2.0+1.6*punch(iTime), 0.2, 0.2));
	return t;
}

float sdSecondTunnel(vec3 pos)
{
	vec3 p = pit(pos - vec3(0.0, 2.0, (iTime - 38.40) * -25.0), iTime);

	// Revolve
	pModPolar(p.xy, 7);
	p -= vec3(7.0, 0.0, 0.0);
	pR(p.xy, radians(90));

	// Repeat
	p = opRep(p, vec3(0.0, 0.0, 1.6));

	float t = sdBox(p, vec3(2.0, 0.2, 0.2+punch(iTime)*0.7));
	return t;
}

vec4 dinerScene(vec3 pos)
{
	// Table
	vec4 obj = vec4(vec3(0.2), sdRoundBox(pos+vec3(0.0, 0.08, 0.0), vec3(10.0, 0.03, 1.4), 0.05));
	obj = opMinColored(obj, vec4(0.3, 0.5, 0.7, sdRoundBox(pos-vec3(0.0, 1.5, 1.5), vec3(10.0, 3.0, 0.03), 0.05)));
	obj = opMinColored(obj, vec4(0.4, 0.7, 0.2, sdRoundBox(pos-vec3(0.0, 2.5, 1.3), vec3(10.0, 0.7, 0.03), 0.05)));
	// Dispenser, share color with bowl to reduce if calls
	float shake = iTime < 6.78 // Increasing vibration between 4.11 and 6.78 seconds
		? max(0.0, (iTime - 4.11) * 0.01)
		: 0.0; 
	float dnb = sdRoundBox(pos-vec3(0.0, 2.5, 0.3)+(shake*vec3(sin(iTime*150.0), cos(iTime*200.0), 0.0)), vec3(0.7, 0.6, 1.0), 0.1);

	// Bikes
	float beat = beat(iTime);
	if (iTime > 6.0 && sdCylinder(pos-vec3(0.0, 0.95, 0.0), vec2(0.9)) < 1e10) // 111 -> 134 FPS (540p)
	{
		float sampleRow = min((iTime - 6.0) / PRECALC_TIME, 1.0);
		float precalcWidth = float(textureSize(iPrecalcTexture, 0).x);
		float cut = sdBox(pos-vec3(0.0, 7.8, 0.3), vec3(2.0, 6.0, 2.0));
		float s = beat >= 32.0
			? 1.0 + punch(iTime) * 0.05
			: 1.0;
		for (int i = 0; i < 5; i++)
		{
			float offs = float(i) * 4.0;
			vec3 bikePosition = texture(iPrecalcTexture, vec2(offs / precalcWidth, sampleRow)).xyz;
			mat3 bikeTranslation = mat3(
				texture(iPrecalcTexture, vec2((offs + 1.0) / precalcWidth, sampleRow)).xyz
				, texture(iPrecalcTexture, vec2((offs + 2.0) / precalcWidth, sampleRow)).xyz
				, texture(iPrecalcTexture, vec2((offs + 3.0) / precalcWidth, sampleRow)).xyz
			);
			// Cut / clip / w/e
			float bike = max(-cut, sdBikeFrame(bikeTranslation * (pos - bikePosition) / s) * s);
			obj = opMinColored(obj, vec4(bikeColor(i), bike));
		}
	}

	// Bowl
	if (beat >= 16.0 && beat < 17.0)
	{
		// Tease the bowl
		float bowl = sdBox(pos - vec3(0.0, 1.0 - punch(iTime), 0.0), vec3(1.0, 0.05, 1.0));
		bowl = max(bowl, sdBowl(pos));
		dnb = min(dnb, bowl);
	}
	else if (beat >= 18.0 && beat < 19.0)
	{
		// Whoop the bowl
		float bowl = sdBox(pos - vec3(0.0, 1.5 - punch(iTime), 0.0), vec3(1.0, 0.6, 1.0));
		bowl = max(-bowl, sdBowl(pos));
		dnb = min(dnb, bowl);
	}
	else if (beat >= 19.0 && beat < 32.0)
	{
		// Show the bowl
		dnb = min(dnb, sdBowl(pos));
	}
	else if (beat >= 32.0)
	{
		// Boop the bowl
		float s = 1.0 + punch(iTime) * 0.05;
		dnb = min(dnb, sdBowl(pos / s) * s);
	}

	// Out the dispenser and bowl
	obj = opMinColored(obj, vec4(0.9, 0.9, 0.9, dnb));

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

	if (beat > 8.0 && beat < 10.0)
	{
		// Cutty cube for matty dude fade in thingy
		vec3 p = pos;
		pR(p.xz, radians(45));
		p += vec3(0.0, 0.0, (beat - 8.0) * 4.0);
		vec4 mat = sdTableMat(pos);
		mat.w = max(-sdBox(p, vec3(3.0, 0.5, 3.0)), mat.w);
		obj = opMinColored(obj, mat);
	}
	else if (beat > 10.0)
	{
		// No more fadey, is there now
		obj = opMinColored(obj, sdTableMat(pos));
	}

	return obj;
}

vec4 tunnelScene(vec3 pos)
{
	float tunnel = sdTunnel(pos);
	vec4 obj = vec4(rgb(64,127,255), tunnel);

	vec3 p = pos - vec3(0.0, 0.0, -18.0);
	pR(p.xz, cos(iTime*4.5)*2.3);
	pR(p.xy, sin(iTime*3.3)*1.8);
	pR(p.yz, -sin(iTime*1.3)*4.6);
	p += vec3(0.0, 0.25, 0.0);
	obj = opMinColored(obj, vec4(bikeColor(4), sdBikeFrame(p / 1.7) * 1.7));

	p = pos - vec3(cos(iTime)*0.8, 2.0+sin(iTime)*0.8, -14.0);
	pR(p.xz, cos(iTime*1.4)*1.6);
	pR(p.xy, sin(iTime*1.2)*2.7);
	pR(p.yz, -sin(iTime*1.7)*3.5);
	p += vec3(0.0, 0.5, 0.0);
	obj = opMinColored(obj, vec4(0.9, 0.9, 0.9, sdBowl(p)));

	p = pos - vec3(0.0, 0.0, -18.0);
	pR(p.xz, cos(iTime*1.8)*1.8);
	pR(p.xy, sin(iTime*1.6)*1.3);
	pR(p.yz, -sin(iTime*1.2)*2.5);
	float chopz = sdChopsticks(p - vec3(1.2, 0.08, -0.2));
	chopz = min(chopz, sdChopsticks(p - vec3(1.249, 0.08, -0.2)));
	obj = opMinColored(obj, vec4(rgb(205,133,63), chopz));

	return obj;
}

vec4 flatScene(vec3 pos)
{
	// Beat synced domain repetition. No, there's absolutely no better way to do this than if/else.
	float beat = beat(iTime);
	if (beat > 104.0)
	{
		pR(pos.xz, radians((beat-104.0)*-25.0));
		pModPolar(pos.xz, beat - 104.0 + punch(iTime));
		pos -= vec3(14.0, 0.0, 0.0);
		// pR(pos.xy, radians(punch(iTime)*30.0));
		pos = opRepLim(pos, 2.5, vec3(4.0, 0.0, 4.0));
	}
	else if (beat > 103.0)
	{
		pos = opRepLim(pos, 2.5, vec3(4.0, 0.0, 4.0));
	}
	else if (beat > 102.0)
	{
		pos = opRepLim(pos, 2.5, vec3(4.0, 0.0, 3.0));
	}
	else if (beat > 101.0)
	{
		pos = opRepLim(pos, 2.5, vec3(3.0, 0.0, 3.0));
	}
	else if (beat > 100.0)
	{
		pos = opRepLim(pos, 2.5, vec3(3.0, 0.0, 2.0));
	}
	else if (beat > 99.0)
	{
		pos = opRepLim(pos, 2.5, vec3(2.0, 0.0, 2.0));
	}
	else if (beat > 98.0)
	{
		pos = opRepLim(pos, 2.5, vec3(2.0, 0.0, 1.0));
	}
	else if (beat > 97.0)
	{
		pos = opRepLim(pos, 2.5, vec3(1.0, 0.0, 1.0));
	}
	else if (beat > 96.0)
	{
		pos = opRepLim(pos, 2.5, vec3(1.0, 0.0, 0.0));
	}

	// Actual content
	return showcase(pos);
}

vec4 secondTunnelScene(vec3 pos)
{
	float beat = beat(iTime);
	if (beat > 128.0)
	{
		pR(pos.yz, radians(beat*25.0));
		pR(pos.xz, radians(90));
		pos += vec3(0.0, 0.0, -22.0);
	}

	float tunnel = sdSecondTunnel(pos + vec3(0.0, 1.5, 0.0));
	vec4 obj = vec4(rgb(64,127,255), tunnel);

	vec3 p = pos - vec3(sin(iTime)*0.5, cos(iTime)*0.5, -18.0);
	pR(p.xz, cos(iTime*4.5)*2.3);
	pR(p.xy, sin(iTime*3.3)*1.8);
	pR(p.yz, -sin(iTime*1.3)*3.2);
	p += vec3(0.0, 0.25, 0.0);
	obj = opMinColored(obj, showcase(p));

	return obj;
}

vec4 scene(vec3 pos)
{
	float beat = beat(iTime);
	if (beat >= 112.0)
	{
		return secondTunnelScene(pos);
	}
	if (beat >= 80.0)
	{
		return flatScene(pos);
	}
	if (beat >= 48.0)
	{
		return tunnelScene(pos);
	}

	return dinerScene(pos);
}

vec4 march(vec3 origin, vec3 direction)
{
	float t = 0.0;

	for (int i = 0; i < iIterations; i++)
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

	vec3 L;
	float beat = beat(iTime);
	if (beat < 48.0)
	{
		L = normalize(iBallPosition);
	}
	else
	{
		L = normalize(vec3(0.417, 0.425, -0.103));
	}

	if (t.w == -1.0)
	{
		// Miss color
		if (beat < 48.0)
		{
			color = vec3(0.9, 0.9, 1.0);
		}
		else
		{
			float kack = 0.8 - abs(rayDirection.y * 0.3 - 0.14) * 1.5;
			color = vec3(kack, kack, 1.0);
		}
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
	vec3 forward;
	float beat = beat(iTime);
	if (beat < 48.0 || (beat > 80.0 && beat < 112.0) || beat > 144.0)
	{
		forward = normalize(iCameraLookAt - iCameraPosition);
	}
	else
	{
		forward = normalize(pit(vec3(0.0, 0.0, -24.0), iTime) - pit(vec3(0.0, 0.0, -25.0), iTime));
	}
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	vec3 up = normalize(cross(forward, right));
	return normalize(uv.x * right + uv.y * up + forward * 2.0);
}

void fragment()
{
	if (iTime > 49.37)
	{
		discard;
	}
	else
	{
		vec2 uv = normalizeScreenCoords(1.0 / SCREEN_PIXEL_SIZE, FRAGCOORD.xy);
		vec3 rayDirection = getCameraRayDirection(uv);

		vec3 cameraPosition;
		float beat = beat(iTime);
		if (beat < 48.0 || (beat > 80.0 && beat < 112.0) || beat > 144.0)
		{
			cameraPosition = iCameraPosition;
		}
		else
		{
			cameraPosition = pit(vec3(0.0, 0.0, -25.0), iTime);
		}

		vec3 col = render(cameraPosition, rayDirection);
		COLOR = vec4(pow(col, vec3(0.4545)), 1);
	}	
}
