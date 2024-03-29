#version 450

/*
   CRT - Guest - Advanced - HD - Pass2
   
   Copyright (C) 2018-2021 guest(r) - guest.r@gmail.com

   Incorporates many good ideas and suggestions from Dr. Venom.
   I would also like give thanks to many Libretro forums members for continuous feedback, suggestions and caring about the shader.
   
   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
   
*/

layout(push_constant) uniform Push
{
	float IOS, brightboost, brightboost1, gsl, scanline1, scanline2, beam_min, beam_max, beam_size,
    glow, vertmask, inters, bloom, halation, scans, gamma_c;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float warpX;
	float warpY;
	float csize;
	float bsize1;
	float intres;
	float c_shape;
	float barspeed;
	float barintensity;
	float bardir;
	float SIGMA_VER;
	float VSHARPNESS;
	float S_SHARPV;
	float VARNG;
	float VSHARP;
	float prescaley;
	float internal_res;
	float scangamma;
	float sborder;
	float scan_falloff;
	float overscanX;
	float overscanY;
	float bloom_dist;	
} global;

#pragma parameter bogus_vfiltering "[ VERTICAL/INTERLACING FILTERING OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter VSHARPNESS "          Vertical Filter Range" 1.0 1.0 8.0 0.25
#define VSHARPNESS global.VSHARPNESS

#pragma parameter SIGMA_VER "          Vertical Blur Sigma" 0.50 0.1 7.0 0.025
#define SIGMA_VER global.SIGMA_VER

#pragma parameter S_SHARPV "          Vert. Substractive Sharpness" 1.0 0.0 2.0 0.10
#define S_SHARPV global.S_SHARPV

#pragma parameter VSHARP "          Vert. Sharpness Definition" 1.25 0.0 2.0 0.10
#define VSHARP global.VSHARP

#pragma parameter VARNG "          Substractive Sharpness Ringing" 0.2 0.0 4.0 0.10
#define VARNG global.VARNG 

#pragma parameter bogus_screen "[ SCREEN OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter intres "          Internal Resolution Y: 224p/240p, 1.5...y-dowsample" 0.0 0.0 6.0 0.5 // Joint parameter with linearize pass, values must match

#pragma parameter IOS "          Integer Scaling: Odd:Y, Even:'X'+Y" 0.0 0.0 4.0 1.0
#define IOS          params.IOS     // Smart Integer Scaling

#pragma parameter warpX "          CurvatureX (default 0.03)" 0.0 0.0 0.25 0.01
#define warpX        global.warpX     // Curvature X

#pragma parameter warpY "          CurvatureY (default 0.04)" 0.0 0.0 0.25 0.01
#define warpY        global.warpY     // Curvature Y

#pragma parameter c_shape "          Curvature Shape" 0.25 0.05 0.60 0.05
#define c_shape        global.c_shape     // curvature shape

#pragma parameter overscanX "          Overscan X original pixels" 0.0 -200.0 200.0 1.0
#define overscanX        global.overscanX     // OverscanX pixels

#pragma parameter overscanY "          Overscan Y original pixels" 0.0 -200.0 200.0 1.0
#define overscanY        global.overscanY     // OverscanY pixels

#pragma parameter csize "          Corner Size" 0.0 0.0 0.25 0.005
#define csize        global.csize     // corner size

#pragma parameter bsize1 "          Border Size" 0.01 0.0 3.0 0.01
#define bsize1        global.bsize1     // border size

#pragma parameter sborder "          Border Intensity" 0.75 0.25 2.0 0.05
#define sborder       global.sborder     // border intensity

#pragma parameter barspeed "          Hum Bar Speed" 50.0 5.0 200.0 1.0

#pragma parameter barintensity "          Hum Bar Intensity" 0.0 -1.0 1.0 0.01

#pragma parameter bardir "          Hum Bar Direction" 0.0 0.0 1.0 1.0

#pragma parameter bogus_brightness "[ BRIGHTNESS SETTINGS ]:" 0.0 0.0 1.0 1.0

#pragma parameter glow "          Glow Strength" 0.08 -2.0 2.0 0.01
#define glow         params.glow     // Glow Strength

#pragma parameter bloom "          Bloom Strength" 0.0 -2.0 2.0 0.05
#define bloom         params.bloom     // bloom effect

#pragma parameter bloom_dist "          Bloom Distribution" 0.0 0.0 2.0 0.05
#define bloom_dist         global.bloom_dist     // bloom effect distribution

#pragma parameter halation "          Halation Strength" 0.0 0.0 2.0 0.025
#define halation         params.halation     // halation effect

#pragma parameter gamma_c "          Gamma correct" 1.0 0.50 2.0 0.02
#define gamma_c   params.gamma_c     // adjust brightness

#pragma parameter brightboost "          Bright Boost Dark Pixels" 1.40 0.25 10.0 0.05
#define brightboost  params.brightboost     // adjust brightness

#pragma parameter brightboost1 "          Bright Boost Bright Pixels" 1.10 0.25 3.00 0.025
#define brightboost1  params.brightboost1     // adjust brightness

#pragma parameter bogus_scanline "[ SCANLINE OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter gsl "          Scanline Type" 0.0 -1.0 2.0 1.0
#define gsl          params.gsl      // Alternate scanlines

#pragma parameter scanline1 "          Scanline Beam Shape Center" 6.0 -20.0 20.0 0.5
#define scanline1    params.scanline1      // scanline param, vertical sharpness

#pragma parameter scanline2 "          Scanline Beam Shape Edges" 8.0 3.0 70.0 1.0 
#define scanline2    params.scanline2      // scanline param, vertical sharpness

#pragma parameter beam_min "          Scanline Shape Dark Pixels" 1.20 0.25 5.0 0.05
#define beam_min     params.beam_min     // dark area beam min - narrow

#pragma parameter beam_max "          Scanline Shape Bright Pixels" 1.00 0.4 3.5 0.025
#define beam_max     params.beam_max     // bright area beam max - wide

#pragma parameter beam_size "          Increased Bright Scanline Beam" 0.60 0.0 1.0 0.05
#define beam_size    params.beam_size     // increased max. beam size

#pragma parameter vertmask "          Scanline Color Deconvergence" 0.0 -1.0 1.0 0.1
#define vertmask     params.vertmask     // Scanline deconvergence colors

#pragma parameter scans "          Scanline Saturation / Mask Falloff" 0.60 0.0 2.5 0.05
#define scans        params.scans     // scanline saturation

#pragma parameter scan_falloff "          Scanline Falloff" 1.0 0.25 2.0 0.05
#define scan_falloff        global.scan_falloff     // scanline falloff

#pragma parameter scangamma "          Scanline Gamma" 2.40 0.5 5.0 0.05
#define scangamma global.scangamma

#pragma parameter prescaley "          Prescale-Y Factor (for xBR...pre-shader...)" 1.0 1.0 5.0 0.25  // Joint parameter with Linearize Pass pass, values must match
#define prescaley        global.prescaley     // prescale-y factor

#pragma parameter internal_res "          Internal Resolution" 1.0 1.0 8.0 0.10
#define internal_res global.internal_res

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define TEX0 vTexCoord

#define OutputSize global.OutputSize
#define gl_FragCoord (vTexCoord * OutputSize.xy)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Pass1;
layout(set = 0, binding = 3) uniform sampler2D LinearizePass;
layout(set = 0, binding = 4) uniform sampler2D BloomPass;
layout(set = 0, binding = 5) uniform sampler2D PrePass;

#define eps 1e-10 

float st(float x)
{
	return exp2(-10.0*x*x);
} 
   
float sw0(float x, float color, float scanline)
{
	float tmp = mix(beam_min, beam_max, color);
	float ex = x*tmp;
	ex = (gsl > -0.5) ? ex*ex : mix(ex*ex, ex*ex*ex, 0.4);
	return exp2(-scanline*ex);
} 

float sw1(float x, float color, float scanline)
{	
	x = mix (x, beam_min*x, max(x-0.4*color,0.0));
	float tmp = mix(1.2*beam_min, beam_max, color);
	float ex = x*tmp;
	return exp2(-scanline*ex*ex);
}    

float sw2(float x, float color, float scanline)
{
	float tmp = mix((2.5-0.5*color)*beam_min, beam_max, color);
	tmp = mix(beam_max, tmp, pow(x, color+0.3));
	float ex = x*tmp;
	return exp2(-scanline*ex*ex);
}  
 

vec3 gc(vec3 c)
{
	float mc = max(max(c.r,c.g),c.b);
	float mg = pow(mc, 1.0/gamma_c);
	return c * mg/(mc + eps);  
}

vec2 Overscan(vec2 pos, float dx, float dy){
	pos=pos*2.0-1.0;    
	pos*=vec2(dx,dy);
	return pos*0.5+0.5;
}  

vec2 Warp(vec2 pos)
{
	pos  = pos*2.0-1.0;    
	pos  = mix(pos, vec2(pos.x*inversesqrt(1.0-c_shape*pos.y*pos.y), pos.y*inversesqrt(1.0-c_shape*pos.x*pos.x)), vec2(warpX, warpY)/c_shape);
	return pos*0.5 + 0.5;
}


float invsqrsigma = 1.0/(2.0*SIGMA_VER*SIGMA_VER*internal_res*internal_res);

float gaussian(float x)
{
	return exp(-x*x*invsqrsigma);
} 

vec3 v_resample (vec2 tex0, vec4 Size) {

	float f = fract(Size.y * tex0.y);
	f = 0.5 - f;
	vec2 tex = tex0;
	tex.y = floor(Size.y *tex.y)*Size.w + 0.5*Size.w;
	vec3 color = 0.0.xxx;
	vec2 dy  = vec2(0.0, Size.w);

	float w = 0.0;
	float wsum = 0.0;
	vec3 pixel;

	vec3 cmax = 0.0.xxx;
	vec3 cmin = 1.0.xxx;
	float vsharpness = VSHARPNESS*internal_res;
	float sharp = gaussian(vsharpness) * S_SHARPV;
	float maxsharp = 0.20;
	float FPR = vsharpness;
	float fpx = 0.0;

	float LOOPSIZE = ceil(2.0*FPR);
	float CLAMPSIZE = round(2.0*LOOPSIZE/3.0);
	
	float n = -LOOPSIZE;
	
	do
	{
		pixel  = COMPAT_TEXTURE(Pass1, tex + n*dy).rgb;

		w = gaussian(n+f) - sharp;
		fpx = abs(n+f-sign(n)*FPR)/FPR;
		if (abs(n) <= CLAMPSIZE) { cmax = max(cmax, pixel); cmin = min(cmin, pixel); }
		if (w < 0.0) w = clamp(w, mix(-maxsharp, 0.0, pow(fpx, VSHARP)), 0.0);
	
		color = color + w * pixel;
		wsum  = wsum + w;

		n = n + 1.0;
			
	} while (n <= LOOPSIZE);

	color = color / wsum;

	color = clamp(mix(clamp(color, cmin, cmax), color, VARNG), 0.0, 1.0);

	return color; 
}


void main()
{
	vec4 SourceSize = vec4(global.SourceSize.x, global.OriginalSize.y, global.SourceSize.z, global.OriginalSize.w);
	float gamma_in = 1.0/COMPAT_TEXTURE(LinearizePass, vec2(0.25,0.25)).a;
	float intera = COMPAT_TEXTURE(LinearizePass, vec2(0.75,0.25)).a;
	bool interb  = (intera < 0.5);

	float SourceY = SourceSize.y;
	float sy = 1.0;
	if (global.intres == 0.5) sy = SourceY/224.0; else
	if (global.intres == 1.0) sy = SourceY/240.0; else
	if (global.intres > 1.25) sy = global.intres;
	SourceSize*=vec4(1.0, 1.0/sy, 1.0, sy); 

	// Calculating texel coordinates
   
	vec2 texcoord = TEX0.xy;

	if (IOS > 0.0 && !interb){
		vec2 ofactor = OutputSize.xy/SourceSize.xy;
		vec2 intfactor = (IOS < 2.5) ? floor(ofactor) : ceil(ofactor);
		vec2 diff = ofactor/intfactor;
		float scan = diff.y;
		texcoord = Overscan(texcoord, scan, scan);
		if (IOS == 1.0 || IOS == 3.0) texcoord = vec2(TEX0.x, texcoord.y);
	}

	texcoord = Overscan(texcoord, (global.OriginalSize.x - overscanX)/global.OriginalSize.x, (global.OriginalSize.y - overscanY)/global.OriginalSize.y);
	
	vec2 pos  = Warp(texcoord);

	float coffset = 0.5;
	
	vec2 ps = SourceSize.zw;
	float OGL2Pos = pos.y * SourceSize.y - coffset;
	float f = fract(OGL2Pos);
	
	vec2 dx = vec2(ps.x,0.0);
	vec2 dy = vec2(0.0, ps.y);
   
	// Reading the texels

	vec2 pC4;
	
	pC4.y = floor(OGL2Pos) * ps.y + 0.5*ps.y; 
	pC4.x = pos.x;
	
	vec3 color1 = COMPAT_TEXTURE(Pass1, pC4      ).rgb;
	vec3 scolor1 = 	COMPAT_TEXTURE(Pass1, pC4      ).aaa;

	color1 = pow(color1, vec3(scangamma/gamma_in));

	if (interb) color1 = v_resample(pos, SourceSize * vec4(1.0, prescaley, 1.0, 1.0/prescaley));
	
	pC4+=dy;
	
	vec3 color2 = COMPAT_TEXTURE(Pass1, pC4      ).rgb;
	vec3 scolor2 = 	COMPAT_TEXTURE(Pass1, pC4      ).aaa;
	
	color2 = pow(color2, vec3(scangamma/gamma_in));
	
	// calculating scanlines

	vec3 ctmp = color1; vec3 mcolor = scolor1; float w3 = 1.0; vec3 color = color1;
	vec3 one = vec3(1.0);

if (!interb)
{	
	float shape1 = mix(scanline1, scanline2, f);
	float shape2 = mix(scanline1, scanline2, 1.0-f);	
	
	float wt1 = st(f);
	float wt2 = st(1.0-f);

	vec3 color00 = color1*wt1 + color2*wt2;
	vec3 scolor0 = scolor1*wt1 + scolor2*wt2;
	
	ctmp = color00/(wt1+wt2);
	vec3 sctmp = max(scolor0/(wt1+wt2), ctmp);
	
	float wf1, wf2;
	
	vec3 cref1 = mix(sctmp, scolor1, beam_size); float creff1 = pow(max(max(cref1.r,cref1.g),cref1.b), scan_falloff);
	vec3 cref2 = mix(sctmp, scolor2, beam_size); float creff2 = pow(max(max(cref2.r,cref2.g),cref2.b), scan_falloff);

	float f1 = f; 
	float f2 = 1.0-f;
	
	if (gsl <  0.5) { wf1 = sw0(f1,creff1,shape1); wf2 = sw0(f2,creff2,shape2);} else
	if (gsl == 1.0) { wf1 = sw1(f1,creff1,shape1); wf2 = sw1(f2,creff2,shape2);} else
	                { wf1 = sw2(f1,creff1,shape1); wf2 = sw2(f2,creff2,shape2);}

	if ((wf1 + wf2) > 1.0) { float wtmp = 1.0/(wf1+wf2); wf1*=wtmp; wf2*=wtmp; }
	
	// Scanline saturation application
	
	vec3 w1 = vec3(wf1); vec3 w2 = vec3(wf2);
	w3 = wf1+wf2;
	
	float mc1 = max(max(color1.r,color1.g),color1.b) + eps;
	float mc2 = max(max(color2.r,color2.g),color2.b) + eps;
	
	cref1 = color1 / mc1; cref1=cref1*cref1; cref1*=cref1;
	cref2 = color2 / mc2; cref2=cref2*cref2; cref2*=cref2;

	w1 = max( mix(w1*mix(one, cref1, scans), w1, wf1*min((1.0+0.15*scans), 1.2)), 0.0); w1 = min(w1*color1, mc1)/(color1 + eps);
	w2 = max( mix(w2*mix(one, cref2, scans), w2, wf2*min((1.0+0.15*scans), 1.2)), 0.0); w2 = min(w2*color2, mc2)/(color2 + eps);
	
	// Scanline Deconvergence
	
	vec3 cd1 = one; vec3 cd2 = one; float vm = sqrt(abs(vertmask));
	
	float v_high1 = 1.0 + 0.3*vm;
	float v_high2 = 1.0 + 0.6*vm;	
	float v_low  = 1.0 - vm;
	
	float ds1 = min(max(1.0-w3*w3, 2.5*f1), 1.0);
	float ds2 = min(max(1.0-w3*w3, 2.5*f2), 1.0);
	
	if (vertmask < 0.0) 
	{
		cd1 = mix(one, vec3(v_high2, v_low, v_low), ds1);
		cd2 = mix(one, vec3(v_low, v_high1, v_high1), ds2);
	}
	else
	{
		cd1 = mix(one, vec3(v_high1, v_low, v_high1), ds1);
		cd2 = mix(one, vec3(v_low, v_high2, v_low), ds2);
	}
	
	color = gc(color1)*w1*cd1 + gc(color2)*w2*cd2;
	color = min(color, 1.0);
}
	
	if (interb) 
	{
		color = gc(color1);
	}

	float colmx = pow(max(max(ctmp.r,ctmp.g),ctmp.b), 1.40/gamma_in);

	if (!interb) color = pow( color, vec3(gamma_in/scangamma) );
  
	FragColor = vec4(color, colmx);
}
