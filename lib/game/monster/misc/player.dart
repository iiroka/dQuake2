/*
 * Copyright (C) = 1997-2001 Id Software, Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version = 2 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., = 59 Temple Place - Suite = 330, Boston, MA
 * = 02111-1307, USA.
 *
 * =======================================================================
 *
 * Player (the arm and the weapons) animation.
 *
 * =======================================================================
 */

const FRAME_stand01 = 0;
const FRAME_stand02 = 1;
const FRAME_stand03 = 2;
const FRAME_stand04 = 3;
const FRAME_stand05 = 4;
const FRAME_stand06 = 5;
const FRAME_stand07 = 6;
const FRAME_stand08 = 7;
const FRAME_stand09 = 8;
const FRAME_stand10 = 9;
const FRAME_stand11 = 10;
const FRAME_stand12 = 11;
const FRAME_stand13 = 12;
const FRAME_stand14 = 13;
const FRAME_stand15 = 14;
const FRAME_stand16 = 15;
const FRAME_stand17 = 16;
const FRAME_stand18 = 17;
const FRAME_stand19 = 18;
const FRAME_stand20 = 19;
const FRAME_stand21 = 20;
const FRAME_stand22 = 21;
const FRAME_stand23 = 22;
const FRAME_stand24 = 23;
const FRAME_stand25 = 24;
const FRAME_stand26 = 25;
const FRAME_stand27 = 26;
const FRAME_stand28 = 27;
const FRAME_stand29 = 28;
const FRAME_stand30 = 29;
const FRAME_stand31 = 30;
const FRAME_stand32 = 31;
const FRAME_stand33 = 32;
const FRAME_stand34 = 33;
const FRAME_stand35 = 34;
const FRAME_stand36 = 35;
const FRAME_stand37 = 36;
const FRAME_stand38 = 37;
const FRAME_stand39 = 38;
const FRAME_stand40 = 39;
const FRAME_run1 = 40;
const FRAME_run2 = 41;
const FRAME_run3 = 42;
const FRAME_run4 = 43;
const FRAME_run5 = 44;
const FRAME_run6 = 45;
const FRAME_attack1 = 46;
const FRAME_attack2 = 47;
const FRAME_attack3 = 48;
const FRAME_attack4 = 49;
const FRAME_attack5 = 50;
const FRAME_attack6 = 51;
const FRAME_attack7 = 52;
const FRAME_attack8 = 53;
const FRAME_pain101 = 54;
const FRAME_pain102 = 55;
const FRAME_pain103 = 56;
const FRAME_pain104 = 57;
const FRAME_pain201 = 58;
const FRAME_pain202 = 59;
const FRAME_pain203 = 60;
const FRAME_pain204 = 61;
const FRAME_pain301 = 62;
const FRAME_pain302 = 63;
const FRAME_pain303 = 64;
const FRAME_pain304 = 65;
const FRAME_jump1 = 66;
const FRAME_jump2 = 67;
const FRAME_jump3 = 68;
const FRAME_jump4 = 69;
const FRAME_jump5 = 70;
const FRAME_jump6 = 71;
const FRAME_flip01 = 72;
const FRAME_flip02 = 73;
const FRAME_flip03 = 74;
const FRAME_flip04 = 75;
const FRAME_flip05 = 76;
const FRAME_flip06 = 77;
const FRAME_flip07 = 78;
const FRAME_flip08 = 79;
const FRAME_flip09 = 80;
const FRAME_flip10 = 81;
const FRAME_flip11 = 82;
const FRAME_flip12 = 83;
const FRAME_salute01 = 84;
const FRAME_salute02 = 85;
const FRAME_salute03 = 86;
const FRAME_salute04 = 87;
const FRAME_salute05 = 88;
const FRAME_salute06 = 89;
const FRAME_salute07 = 90;
const FRAME_salute08 = 91;
const FRAME_salute09 = 92;
const FRAME_salute10 = 93;
const FRAME_salute11 = 94;
const FRAME_taunt01 = 95;
const FRAME_taunt02 = 96;
const FRAME_taunt03 = 97;
const FRAME_taunt04 = 98;
const FRAME_taunt05 = 99;
const FRAME_taunt06 = 100;
const FRAME_taunt07 = 101;
const FRAME_taunt08 = 102;
const FRAME_taunt09 = 103;
const FRAME_taunt10 = 104;
const FRAME_taunt11 = 105;
const FRAME_taunt12 = 106;
const FRAME_taunt13 = 107;
const FRAME_taunt14 = 108;
const FRAME_taunt15 = 109;
const FRAME_taunt16 = 110;
const FRAME_taunt17 = 111;
const FRAME_wave01 = 112;
const FRAME_wave02 = 113;
const FRAME_wave03 = 114;
const FRAME_wave04 = 115;
const FRAME_wave05 = 116;
const FRAME_wave06 = 117;
const FRAME_wave07 = 118;
const FRAME_wave08 = 119;
const FRAME_wave09 = 120;
const FRAME_wave10 = 121;
const FRAME_wave11 = 122;
const FRAME_point01 = 123;
const FRAME_point02 = 124;
const FRAME_point03 = 125;
const FRAME_point04 = 126;
const FRAME_point05 = 127;
const FRAME_point06 = 128;
const FRAME_point07 = 129;
const FRAME_point08 = 130;
const FRAME_point09 = 131;
const FRAME_point10 = 132;
const FRAME_point11 = 133;
const FRAME_point12 = 134;
const FRAME_crstnd01 = 135;
const FRAME_crstnd02 = 136;
const FRAME_crstnd03 = 137;
const FRAME_crstnd04 = 138;
const FRAME_crstnd05 = 139;
const FRAME_crstnd06 = 140;
const FRAME_crstnd07 = 141;
const FRAME_crstnd08 = 142;
const FRAME_crstnd09 = 143;
const FRAME_crstnd10 = 144;
const FRAME_crstnd11 = 145;
const FRAME_crstnd12 = 146;
const FRAME_crstnd13 = 147;
const FRAME_crstnd14 = 148;
const FRAME_crstnd15 = 149;
const FRAME_crstnd16 = 150;
const FRAME_crstnd17 = 151;
const FRAME_crstnd18 = 152;
const FRAME_crstnd19 = 153;
const FRAME_crwalk1 = 154;
const FRAME_crwalk2 = 155;
const FRAME_crwalk3 = 156;
const FRAME_crwalk4 = 157;
const FRAME_crwalk5 = 158;
const FRAME_crwalk6 = 159;
const FRAME_crattak1 = 160;
const FRAME_crattak2 = 161;
const FRAME_crattak3 = 162;
const FRAME_crattak4 = 163;
const FRAME_crattak5 = 164;
const FRAME_crattak6 = 165;
const FRAME_crattak7 = 166;
const FRAME_crattak8 = 167;
const FRAME_crattak9 = 168;
const FRAME_crpain1 = 169;
const FRAME_crpain2 = 170;
const FRAME_crpain3 = 171;
const FRAME_crpain4 = 172;
const FRAME_crdeath1 = 173;
const FRAME_crdeath2 = 174;
const FRAME_crdeath3 = 175;
const FRAME_crdeath4 = 176;
const FRAME_crdeath5 = 177;
const FRAME_death101 = 178;
const FRAME_death102 = 179;
const FRAME_death103 = 180;
const FRAME_death104 = 181;
const FRAME_death105 = 182;
const FRAME_death106 = 183;
const FRAME_death201 = 184;
const FRAME_death202 = 185;
const FRAME_death203 = 186;
const FRAME_death204 = 187;
const FRAME_death205 = 188;
const FRAME_death206 = 189;
const FRAME_death301 = 190;
const FRAME_death302 = 191;
const FRAME_death303 = 192;
const FRAME_death304 = 193;
const FRAME_death305 = 194;
const FRAME_death306 = 195;
const FRAME_death307 = 196;
const FRAME_death308 = 197;

const MODEL_SCALE = 1.000000;
