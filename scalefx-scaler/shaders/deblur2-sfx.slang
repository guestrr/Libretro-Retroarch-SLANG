#version 450

/*
   Deblur - ScaleFX version
   
   Copyright (C) 2020 guest(r) - guest.r@gmail.com

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
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float DEBLURSFX;
	float SFXSHARP;
} params;


#pragma parameter DEBLURSFX "Deblur Strength" 3.0 2.0 7.0 1.0
#define DEBLURSFX params.DEBLURSFX

#pragma parameter SFXSHARP "ScaleFX Sharpness" 1.5 0.5 7.0 0.5
#define SFXSHARP params.SFXSHARP


layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D SfxPass;

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize params.SourceSize

void main()
{
		vec3 color = COMPAT_TEXTURE(Source, vTexCoord).rgb;

		vec2 dx  = vec2(SourceSize.z, 0.0);	
		vec2 dy  = vec2(0.0, SourceSize.w);

		vec3 pixel;
		float x;
		vec3  res;
		vec3 cmax = 0.0.xxx;
		vec3 cmin = 1.0.xxx;
		float LOOPSIZE = 2.0;
		
		float y = -2.0;

		do
		{
			x = -LOOPSIZE;
	
			do
			{
				pixel  = COMPAT_TEXTURE(Source, vTexCoord + x*dx + y*dy).rgb;
				cmax = max(cmax, pixel); cmin = min(cmin, pixel);
				x = x + 1.0;
			
			} while (x <= LOOPSIZE);
		
			y = y + 1.0;
		
		} while (y <= LOOPSIZE);
	
		res = color;
		vec3 contrast = cmax - cmin + 0.000001;
		vec3 df1, df2, d1, d2, ratio;
		df1 = color - cmin; d1 = df1;
		df2 = cmax - color; d2 = df2;

		ratio = abs(df1-df2)/(df1+df2+0.0000001);
		df1 = df1/contrast; df1*=df1;
		df2 = df2/contrast; df2*=df2;
		
		x = 1.0;
		
		while (x < DEBLURSFX)
		{
			res = mix(res, (cmax*df1 + cmin*df2)/(df1+df2), ratio);
			df1*=df1; df2*=df2;
			x = x + 1.0;
		}
		
		float mx = 0.0;
		float nx = 3.0;
		vec3 nmin;
		vec3 nmax;
		nmax = 0.0.xxx;
		nmin = 1.0.xxx;
		
		dx = vec2(params.OriginalSize.z, 0.0)/3.0;
		dy = vec2(0.0, params.OriginalSize.w)/3.0;
		vec2 tex = floor(3.0*params.OriginalSize.xy * vTexCoord)*params.OriginalSize.zw/3.0 + 0.5/3.0*params.OriginalSize.zw;

		float w;
		float wsum = 0.0;
		vec3 ref = 0.0.xxx;

		LOOPSIZE = 1.0;
		
		y = -LOOPSIZE;
		
		do
		{
			x = -LOOPSIZE;
	
			do
			{
				pixel  = COMPAT_TEXTURE(SfxPass, tex + x*dx + y*dy).rgb;
				w = dot(res-pixel, res-pixel) + 0.00001;
				w=1.0/pow(w,SFXSHARP);
				ref = ref + w*pixel;
				wsum = wsum + w;
				x = x + 1.0;
			
			} while (x <= LOOPSIZE);
		
			y = y + 1.0;
		
		} while (y <= LOOPSIZE);

		color = ref/wsum; 

		FragColor = vec4(color, 1.0);
}
