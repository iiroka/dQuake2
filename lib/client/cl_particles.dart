/*
 * Copyright (C) 1997-2001 Id Software, Inc.
 * Copyright (C) 2019      Iiro Kaihlaniemi
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or (at
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 *
 * =======================================================================
 *
 * This file implements all generic particle stuff
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/shared/shared.dart';
import 'client.dart';
import 'vid/ref.dart';
import 'cl_view.dart' show V_AddParticle;

cparticle_t active_particles, free_particles;
List<cparticle_t> particles = List.generate(MAX_PARTICLES, (i) => cparticle_t());
// int cl_numparticles = MAX_PARTICLES;

CL_ClearParticles() {
	int i;

	free_particles = particles[0];
	active_particles = null;

	for (i = 0; i < particles.length - 1; i++) {
		particles[i].next = particles[i + 1];
	}

	particles[particles.length - 1].next = null;
}

CL_ParticleEffect(List<double> org, List<double> dir, int color, int count) {

	for (int i = 0; i < count; i++) {
		if (free_particles == null) {
      print("CL_ParticleEffect - no free");
			return;
		}

		var p = free_particles;
		free_particles = p.next;
		p.next = active_particles;
		active_particles = p;

		p.time = cl.time.toDouble();
		p.color = (color + (randk() & 7)).toDouble();
		double d = (randk() & 31).toDouble();

		for (int j = 0; j < 3; j++) {
			p.org[j] = org[j] + ((randk() & 7) - 4) + d * dir[j];
			p.vel[j] = crandk() * 20;
		}

		p.accel[0] = p.accel[1] = 0;
		p.accel[2] = -PARTICLE_GRAVITY + 0.2;
		p.alpha = 1.0;

		p.alphavel = -1.0 / (0.5 + frandk() * 0.3);
	}
}

CL_ParticleEffect2(List<double> org, List<double> dir, int color, int count) {

	final time = cl.time.toDouble();

	for (int i = 0; i < count; i++) {
		if (free_particles == null) {
			return;
		}

		final p = free_particles;
		free_particles = p.next;
		p.next = active_particles;
		active_particles = p;

		p.time = time;
		p.color = (color + (randk() & 7)).toDouble();

		final d = randk() & 7;

		for (int j = 0; j < 3; j++) {
			p.org[j] = org[j] + ((randk() & 7) - 4) + d * dir[j];
			p.vel[j] = crandk() * 20;
		}

		p.accel[0] = p.accel[1] = 0;
		p.accel[2] = (-PARTICLE_GRAVITY).toDouble();
		p.alpha = 1.0;

		p.alphavel = -1.0 / (0.5 + frandk() * 0.3);
	}
}


CL_AddParticles() {
	cparticle_t active, tail, next;

	for (cparticle_t p = active_particles; p != null; p = next) {
		next = p.next;

    double time, alpha;

		if (p.alphavel != INSTANT_PARTICLE) {
			time = (cl.time - p.time) * 0.001;
			alpha = p.alpha + time * p.alphavel;

			if (alpha <= 0) {
				/* faded out */
				p.next = free_particles;
				free_particles = p;
				continue;
			}
		}
		else
		{
			time = 0.0;
			alpha = p.alpha;
		}

		p.next = null;

		if (tail == null) {
			active = tail = p;
		} else {
			tail.next = p;
			tail = p;
		}

		if (alpha > 1.0)
		{
			alpha = 1;
		}

		int color = p.color.toInt();
		double time2 = time * time;

    List<double> org = List.generate(3, (i) => p.org[i] + p.vel[i] * time + p.accel[i] * time2);

		V_AddParticle(org, color, alpha);

		if (p.alphavel == INSTANT_PARTICLE) {
			p.alphavel = 0.0;
			p.alpha = 0.0;
		}
	}

	active_particles = active;
}
