#version 300 es
precision mediump float;

// uniform mediump isampler2D u_texture;

flat in int   vi_i;
flat in int   vi_j;
in float vf_x;
in float vf_y;

in vec4 outColorVS;

out vec4 outColor;

void main() {
  outColor = outColorVS;
//  outColor = vec4( (1.0 + vf_x) / 2.0,(1.0 + vf_y) / 2.0, 0.0,1.0);
//   outColor = vec4( 0.0,0.0,0.0,1.0);
}
