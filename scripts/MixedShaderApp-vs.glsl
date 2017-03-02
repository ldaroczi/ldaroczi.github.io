#version 300 es
precision mediump float;

uniform vec2               resolution;
uniform vec2               dataSize;
uniform mediump isampler2D u_texture;

uniform float              u_minValue;
uniform vec4               u_minColor;
uniform sampler2D          u_colormap;
uniform float              u_maxValue;
uniform vec4               u_maxColor;

uniform int   ui_width;
uniform int   ui_height;
uniform float uf_x0;
uniform float uf_dx;
uniform float uf_y0;
uniform float uf_dy;

flat out int   vi_i;
flat out int   vi_j;
out float vf_x;
out float vf_y;

out vec4 outColorVS;

flat out int calculated;

void main() {
  vi_i = gl_VertexID % ui_width;
  vi_j = gl_VertexID / ui_width;
  vf_x = uf_x0 + float(vi_i) * uf_dx;
  vf_y = uf_y0 + float(vi_j) * uf_dy;
  gl_Position = vec4( vf_x , vf_y , 0.0 ,1.0);
  gl_PointSize = 1.0;

  if (gl_VertexID % 2 == 0) {
      int iMinValue = int(u_minValue);
      int fromX = int( float(vi_i) * dataSize.x / resolution.x );
      int fromY = int( float(vi_j) * dataSize.y / resolution.y );
      int toX   = int( (float(vi_i) + 1.0) * dataSize.x / resolution.x );
      int toY   = int( (float(vi_j) + 1.0) * dataSize.y / resolution.y );
      if (toX == fromX) toX = toX + 1;
      if (toY == fromY) toY = toY + 1;
      int maxValue = -32767;
      for (int x=fromX; x < toX; x++) {
        for (int y=fromY; y < toY; y++) {
            ivec4 value = texelFetch(u_texture, ivec2(x,y), 0);
            if (maxValue < value.x) maxValue = value.x;
        }
      }
      float z = float(maxValue);
      if (z <= u_minValue) {
        outColorVS = u_minColor;
      } else if (u_maxValue <= z) {
        outColorVS = u_maxColor;
      } else {
         outColorVS = texelFetch ( u_colormap, ivec2( maxValue - iMinValue , 0 ),0 );
      }
      calculated = 1;
  } else {
      calculated = 0;
  }
}
