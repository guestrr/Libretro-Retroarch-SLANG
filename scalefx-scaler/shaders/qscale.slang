#version 450

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
   float QAA;
} global;

#pragma parameter QAA "QAA Filter Range" 0.5 0.0 2.0 0.025
#define QAA global.QAA 

vec3 dt = vec3(1.0);

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec4 t1;
layout(location = 2) out vec4 t2;
layout(location = 3) out vec4 t3;
layout(location = 4) out vec4 t4;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   float x = QAA * global.SourceSize.z;
   float y = QAA * global.SourceSize.w;
   vec2 dg1 = vec2( x, y);
   vec2 dg2 = vec2( x,-y);   
   t1 = vec4(vTexCoord - dg1, vTexCoord);
   t2 = vec4(vTexCoord - dg2, vTexCoord);
   t3 = vec4(vTexCoord + dg1, vTexCoord);
   t4 = vec4(vTexCoord + dg2, vTexCoord);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec4 t1;
layout(location = 2) in vec4 t2;
layout(location = 3) in vec4 t3;
layout(location = 4) in vec4 t4;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


void main()
{
   vec3 c00 = texture(Source, t1.xy).xyz; 
   vec3 c20 = texture(Source, t2.xy).xyz; 
   vec3 c11 = texture(Source, vTexCoord).xyz; 
   vec3 c02 = texture(Source, t4.xy).xyz; 
   vec3 c22 = texture(Source, t3.xy).xyz; 

   float md1 = dot(abs(c00 - c22), dt) + 0.0000001;
   float md2 = dot(abs(c02 - c20), dt) + 0.0000001;

   float w1 = md2;
   float w2 = md1;
   float w3 = md2;
   float w4 = md1;

   c11 = (w1 * c00 + w2 * c20 + w3 * c22 + w4 * c02) / (w1+w2+w3+w4);

   FragColor = vec4(c11, 1.0);
}