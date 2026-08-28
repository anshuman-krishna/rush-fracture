// Rush Fracture — "Grafted Brood" bio-mechanical art lane.
// One shared material set + one shared vocabulary of parts across every entity,
// so nine unrelated silhouettes still read as the same world.
// Units: meters, y-up, each object recentered with its lowest point at y=0.
// Every mesh + material is named: OBJ o/usemtl entries and GLB node names.

export const ENTITIES = [
  'pulse_rifle', 'scatter_cannon', 'beam_emitter',
  'chaser', 'tank', 'sniper', 'shooter', 'dasher', 'exploder', 'support', 'displacer',
  'titan', 'warden', 'obstacles',
];

function ctx(THREE) {
  const M = {
    chitin: new THREE.MeshStandardMaterial({ color: 0x584451, roughness: 0.48, metalness: 0.2, name: 'chitin' }),
    bone: new THREE.MeshStandardMaterial({ color: 0xc9b9a2, roughness: 0.56, metalness: 0.05, name: 'bone_carapace' }),
    membrane: new THREE.MeshStandardMaterial({ color: 0x9c4a5f, roughness: 0.26, metalness: 0.0, name: 'membrane', transparent: true, opacity: 0.9 }),
    glow: new THREE.MeshStandardMaterial({ color: 0x9dff5c, emissive: 0x9dff5c, emissiveIntensity: 1.7, roughness: 0.2, metalness: 0.0, name: 'biolum' }),
    graft: new THREE.MeshStandardMaterial({ color: 0x8b968f, roughness: 0.34, metalness: 0.38, name: 'grafted_steel' }),
  };

  const add = (parent, geo, mat, name, pos = [0, 0, 0], rot = [0, 0, 0], scale = null) => {
    const m = new THREE.Mesh(geo, mat);
    m.name = name;
    m.position.set(...pos);
    m.rotation.set(...rot);
    if (scale) m.scale.set(...scale);
    parent.add(m);
    return m;
  };
  const grp = (parent, name, pos = [0, 0, 0], rot = [0, 0, 0]) => {
    const g = new THREE.Group();
    g.name = name;
    g.position.set(...pos);
    g.rotation.set(...rot);
    parent.add(g);
    return g;
  };
  // segmented carapace ring stack — the lane's signature "grown, not built" read
  const ribStack = (parent, name, mat, { count, from, to, r0, r1, tube = 0.014, axis = 'z' }) => {
    for (let i = 0; i < count; i++) {
      const t = count === 1 ? 0 : i / (count - 1);
      const r = r0 + (r1 - r0) * t;
      const z = from + (to - from) * t;
      const rot = axis === 'z' ? [0, Math.PI / 2, 0] : [Math.PI / 2, 0, 0];
      const pos = axis === 'z' ? [0, 0, z] : [0, z, 0];
      add(parent, new THREE.TorusGeometry(r, tube, 10, 26), mat, `${name}_${i + 1}`, pos, rot);
    }
  };
  const spur = (parent, name, mat, pos, rot, r = 0.03, len = 0.16) =>
    add(parent, new THREE.ConeGeometry(r, len, 7), mat, name, pos, rot);
  // two-segment limb + joint bulb + claw
  const limb = (parent, name, mat, { at, upper, lower, r, a1, a2, claw = 0.09, spread = 0 }) => {
    const g = grp(parent, name, at, [a1, spread, 0]);
    add(g, new THREE.CapsuleGeometry(r, upper, 4, 14), mat, `${name}_upper`, [0, -upper / 2, 0]);
    add(g, new THREE.SphereGeometry(r * 1.35, 18, 14), mat, `${name}_knee`, [0, -upper, 0]);
    const lo = grp(g, `${name}_lower_grp`, [0, -upper, 0], [a2, 0, 0]);
    add(lo, new THREE.CapsuleGeometry(r * 0.78, lower, 4, 14), mat, `${name}_lower`, [0, -lower / 2, 0]);
    add(lo, new THREE.ConeGeometry(r * 0.9, claw, 6), M.bone, `${name}_claw`, [0, -lower - claw * 0.35, 0.01], [Math.PI, 0, 0]);
    return g;
  };
  return { M, add, grp, ribStack, spur, limb };
}

/* ============================ weapons ============================ */

function pulseRifle(THREE, c, root) {
  const { M, add, grp, ribStack, spur } = c;
  // "Grafted Carbine" — a symbiont clamped to the forearm; the shell is armour, the sac is the magazine.
  const cuff = grp(root, 'forearm_cuff', [0, 0, 0.28]);
  add(cuff, new THREE.CylinderGeometry(0.062, 0.07, 0.16, 24, 1, true), M.chitin, 'cuff_shell', [0, 0, 0], [Math.PI / 2, 0, 0]);
  ribStack(cuff, 'cuff_rib', M.bone, { count: 3, from: -0.06, to: 0.06, r0: 0.064, r1: 0.071, tube: 0.008 });
  add(cuff, new THREE.SphereGeometry(0.03, 20, 14), M.glow, 'cuff_nerve_node', [0, 0.058, 0.02]);

  const thorax = grp(root, 'thorax', [0, 0.005, 0.06]);
  add(thorax, new THREE.SphereGeometry(0.075, 28, 20), M.chitin, 'thorax_shell', [0, 0, 0], [0, 0, 0], [1, 0.86, 2.4]);
  add(thorax, new THREE.SphereGeometry(0.052, 24, 18), M.membrane, 'nutrient_sac', [0, -0.028, 0.02], [0, 0, 0], [1, 0.8, 1.8]);
  add(thorax, new THREE.SphereGeometry(0.03, 22, 16), M.glow, 'pulse_core', [0, -0.022, -0.01]);
  [-1, 1].forEach((s) => {
    for (let i = 0; i < 4; i++) {
      add(thorax, new THREE.BoxGeometry(0.006, 0.022, 0.03), M.membrane, `gill_${s > 0 ? 'r' : 'l'}_${i + 1}`, [s * 0.062, 0.012, -0.06 + i * 0.042], [0, 0, s * 0.2]);
    }
    add(thorax, new THREE.BoxGeometry(0.008, 0.03, 0.19), M.glow, `vein_${s > 0 ? 'r' : 'l'}`, [s * 0.058, -0.03, 0.01]);
  });

  const barrel = grp(root, 'barrel_limb', [0, 0.005, -0.26]);
  add(barrel, new THREE.CylinderGeometry(0.026, 0.034, 0.34, 20), M.chitin, 'barrel_core', [0, 0, 0], [Math.PI / 2, 0, 0]);
  ribStack(barrel, 'barrel_rib', M.bone, { count: 7, from: -0.15, to: 0.15, r0: 0.031, r1: 0.041, tube: 0.011 });
  spur(barrel, 'ventral_spur', M.bone, [0, -0.045, 0.02], [Math.PI * 0.44, 0, 0], 0.022, 0.2);

  const maw = grp(root, 'muzzle_maw', [0, 0.005, -0.45]);
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2 + Math.PI / 4;
    add(maw, new THREE.ConeGeometry(0.016, 0.11, 6), M.bone, `clamp_${i + 1}`,
      [Math.cos(a) * 0.026, Math.sin(a) * 0.026, -0.03], [-Math.PI / 2 + 0.22, 0, a]);
  }
  add(maw, new THREE.SphereGeometry(0.019, 20, 14), M.glow, 'muzzle_gland', [0, 0, 0.005]);

  const grip = grp(root, 'grip_spine', [0, -0.11, 0.14], [-0.26, 0, 0]);
  add(grip, new THREE.CapsuleGeometry(0.028, 0.11, 4, 16), M.chitin, 'grip_shaft', [0, 0, 0]);
  for (let i = 0; i < 3; i++) {
    add(grip, new THREE.SphereGeometry(0.02, 16, 12), M.bone, `knuckle_nub_${i + 1}`, [0, 0.04 - i * 0.04, -0.026]);
  }
  add(root, new THREE.TorusGeometry(0.03, 0.008, 10, 22, Math.PI * 1.2), M.bone, 'trigger_hook', [0, -0.07, 0.075], [0, Math.PI / 2, -0.5]);
  add(root, new THREE.SphereGeometry(0.014, 16, 12), M.glow, 'trigger_nerve', [0, -0.055, 0.082]);
}

function scatterCannon(THREE, c, root) {
  const { M, add, grp, ribStack, spur } = c;
  // "Sporecaster" — a burst egg-sac; seven nostril tubes, one per pellet.
  const chamber = grp(root, 'spore_chamber', [0, 0.02, 0.04]);
  add(chamber, new THREE.SphereGeometry(0.11, 30, 22), M.chitin, 'chamber_shell', [0, 0, 0], [0, 0, 0], [1, 0.95, 1.5]);
  add(chamber, new THREE.SphereGeometry(0.085, 26, 20), M.membrane, 'chamber_bladder', [0, -0.01, 0.02], [0, 0, 0], [1, 0.9, 1.2]);
  add(chamber, new THREE.SphereGeometry(0.042, 22, 16), M.glow, 'seed_core', [0, -0.005, 0]);
  ribStack(chamber, 'sinew_strap', M.bone, { count: 4, from: -0.11, to: 0.11, r0: 0.086, r1: 0.086, tube: 0.012 });

  const rosette = grp(root, 'nostril_rosette', [0, 0.02, -0.2]);
  add(rosette, new THREE.CylinderGeometry(0.085, 0.062, 0.1, 24), M.chitin, 'rosette_base', [0, 0, 0.05], [Math.PI / 2, 0, 0]);
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 2;
    const r = i === 0 ? 0 : 0.05;
    const x = i === 0 ? 0 : Math.cos(a) * r;
    const y = i === 0 ? 0 : Math.sin(a) * r;
    const tube = grp(rosette, `nostril_${i + 1}`, [x, y, 0], [0, 0, 0]);
    add(tube, new THREE.CylinderGeometry(0.019, 0.023, 0.17, 14), M.chitin, `nostril_shaft_${i + 1}`, [0, 0, -0.06], [Math.PI / 2, 0, 0]);
    add(tube, new THREE.TorusGeometry(0.021, 0.007, 8, 18), M.bone, `nostril_lip_${i + 1}`, [0, 0, -0.145], [0, Math.PI / 2, 0]);
    add(tube, new THREE.SphereGeometry(0.011, 14, 10), M.glow, `nostril_gland_${i + 1}`, [0, 0, -0.13]);
  }

  const grip = grp(root, 'grip_spine', [0, -0.1, 0.16], [-0.24, 0, 0]);
  add(grip, new THREE.CapsuleGeometry(0.03, 0.12, 4, 16), M.chitin, 'grip_shaft', [0, 0, 0]);
  for (let i = 0; i < 3; i++) {
    add(grip, new THREE.SphereGeometry(0.021, 16, 12), M.bone, `knuckle_nub_${i + 1}`, [0, 0.045 - i * 0.042, -0.028]);
  }
  add(root, new THREE.TorusGeometry(0.032, 0.009, 10, 22, Math.PI * 1.2), M.bone, 'trigger_hook', [0, -0.058, 0.1], [0, Math.PI / 2, -0.5]);
  spur(root, 'shoulder_brace', M.bone, [0, 0.05, 0.24], [-Math.PI * 0.42, 0, 0], 0.035, 0.22);
  add(root, new THREE.SphereGeometry(0.026, 18, 14), M.membrane, 'recoil_bladder', [0, -0.02, 0.2]);
}

function beamEmitter(THREE, c, root) {
  const { M, add, grp, ribStack } = c;
  // "Stinger" — a wasp limb; three heat sacs swell and flush as heat builds, vent when it locks out.
  const base = grp(root, 'root_socket', [0, 0.01, 0.2]);
  add(base, new THREE.CylinderGeometry(0.058, 0.075, 0.2, 24), M.chitin, 'socket_shell', [0, 0, 0], [Math.PI / 2, 0, 0]);
  add(base, new THREE.TorusGeometry(0.062, 0.012, 12, 26), M.graft, 'socket_clamp', [0, 0, -0.06], [0, Math.PI / 2, 0]);
  add(base, new THREE.SphereGeometry(0.026, 20, 14), M.glow, 'socket_nerve', [0, 0.05, 0.03]);

  const spine = grp(root, 'spine', [0, 0.01, -0.02]);
  add(spine, new THREE.CylinderGeometry(0.034, 0.05, 0.3, 20), M.chitin, 'spine_shaft', [0, 0, 0], [Math.PI / 2, 0, 0]);
  ribStack(spine, 'spine_rib', M.bone, { count: 5, from: -0.13, to: 0.13, r0: 0.038, r1: 0.054, tube: 0.01 });
  [-0.1, 0.02, 0.14].forEach((z, i) => {
    add(spine, new THREE.SphereGeometry(0.038, 22, 16), M.membrane, `heat_sac_${i + 1}`, [0, 0.05, z], [0, 0, 0], [0.8, 1, 1.1]);
    add(spine, new THREE.SphereGeometry(0.017, 16, 12), M.glow, `heat_sac_core_${i + 1}`, [0, 0.05, z]);
    [-1, 1].forEach((s) => {
      add(spine, new THREE.CylinderGeometry(0.008, 0.011, 0.03, 12), M.bone, `vent_port_${i + 1}_${s > 0 ? 'r' : 'l'}`, [s * 0.05, 0.03, z], [0, 0, Math.PI / 2 * s]);
    });
  });

  const needle = grp(root, 'proboscis', [0, 0.01, -0.35]);
  add(needle, new THREE.CylinderGeometry(0.012, 0.03, 0.36, 18), M.bone, 'needle_shaft', [0, 0, -0.02], [Math.PI / 2, 0, 0]);
  ribStack(needle, 'needle_ring', M.chitin, { count: 4, from: 0.1, to: -0.12, r0: 0.026, r1: 0.015, tube: 0.007 });
  for (let i = 0; i < 3; i++) {
    const a = (i / 3) * Math.PI * 2;
    add(needle, new THREE.ConeGeometry(0.008, 0.09, 5), M.bone, `guide_barb_${i + 1}`,
      [Math.cos(a) * 0.016, Math.sin(a) * 0.016, -0.14], [-Math.PI / 2 + 0.12, 0, a]);
  }
  add(needle, new THREE.SphereGeometry(0.013, 18, 12), M.glow, 'emission_tip', [0, 0, -0.2]);

  const grip = grp(root, 'grip_spine', [0, -0.11, 0.1], [-0.28, 0, 0]);
  add(grip, new THREE.CapsuleGeometry(0.028, 0.115, 4, 16), M.chitin, 'grip_shaft', [0, 0, 0]);
  add(grip, new THREE.BoxGeometry(0.03, 0.06, 0.008), M.glow, 'heat_readout', [0, -0.02, 0.032]);
  add(root, new THREE.TorusGeometry(0.03, 0.008, 10, 22, Math.PI * 1.2), M.bone, 'trigger_hook', [0, -0.07, 0.05], [0, Math.PI / 2, -0.5]);
}

/* ============================ enemies ============================ */

function chaser(THREE, c, root) {
  const { M, add, grp, ribStack, spur, limb } = c;
  // "Ripper Hound" — blind, quadrupedal, all forward mass. 1.7 m long, 1.0 m at the shoulder.
  const torso = grp(root, 'torso', [0, 0.72, 0]);
  add(torso, new THREE.CapsuleGeometry(0.24, 0.6, 6, 22), M.chitin, 'torso_shell', [0, 0, 0], [Math.PI / 2, 0, 0]);
  ribStack(torso, 'dorsal_rib', M.bone, { count: 6, from: -0.34, to: 0.3, r0: 0.25, r1: 0.22, tube: 0.028 });
  add(torso, new THREE.SphereGeometry(0.19, 24, 18), M.chitin, 'shoulder_mass', [0, 0.06, -0.32], [0, 0, 0], [1.5, 1, 1]);
  add(torso, new THREE.SphereGeometry(0.14, 22, 16), M.membrane, 'flank_sac', [0, -0.12, 0.16], [0, 0, 0], [1.1, 0.8, 1.5]);
  [-1, 1].forEach((s) => add(torso, new THREE.BoxGeometry(0.02, 0.06, 0.5), M.glow, `flank_seam_${s > 0 ? 'r' : 'l'}`, [s * 0.225, -0.02, 0.02]));
  for (let i = 0; i < 5; i++) spur(torso, `dorsal_spur_${i + 1}`, M.bone, [0, 0.26, -0.3 + i * 0.15], [-0.35, 0, 0], 0.035, 0.2);

  const head = grp(root, 'head', [0, 0.78, -0.62], [0.12, 0, 0]);
  add(head, new THREE.SphereGeometry(0.15, 24, 18), M.chitin, 'skull_plate', [0, 0, 0], [0, 0, 0], [1, 0.85, 1.5]);
  add(head, new THREE.BoxGeometry(0.17, 0.05, 0.16), M.bone, 'upper_jaw', [0, -0.07, -0.16], [0.18, 0, 0]);
  add(head, new THREE.BoxGeometry(0.15, 0.045, 0.14), M.bone, 'lower_jaw', [0, -0.12, -0.15], [-0.14, 0, 0]);
  for (let i = 0; i < 4; i++) {
    [-1, 1].forEach((s) => add(head, new THREE.ConeGeometry(0.016, 0.07, 5), M.bone, `fang_${s > 0 ? 'r' : 'l'}_${i + 1}`,
      [s * 0.055, -0.1, -0.1 - i * 0.045], [Math.PI, 0, 0]));
  }
  add(head, new THREE.SphereGeometry(0.05, 20, 14), M.glow, 'sensory_bulb', [0, 0.06, -0.08], [0, 0, 0], [1.6, 0.5, 0.6]);

  limb(root, 'foreleg_l', M.chitin, { at: [-0.19, 0.72, -0.3], upper: 0.34, lower: 0.34, r: 0.075, a1: 0.5, a2: -0.95, spread: 0.12 });
  limb(root, 'foreleg_r', M.chitin, { at: [0.19, 0.72, -0.3], upper: 0.34, lower: 0.34, r: 0.075, a1: 0.3, a2: -0.75, spread: -0.12 });
  limb(root, 'hindleg_l', M.chitin, { at: [-0.2, 0.7, 0.3], upper: 0.36, lower: 0.32, r: 0.085, a1: -0.45, a2: 0.9, spread: 0.1 });
  limb(root, 'hindleg_r', M.chitin, { at: [0.2, 0.7, 0.3], upper: 0.36, lower: 0.32, r: 0.085, a1: -0.25, a2: 0.7, spread: -0.1 });

  const tail = grp(root, 'tail', [0, 0.78, 0.34], [0.5, 0, 0]);
  add(tail, new THREE.CapsuleGeometry(0.05, 0.3, 4, 14), M.chitin, 'tail_base', [0, 0.16, 0]);
  add(tail, new THREE.ConeGeometry(0.045, 0.28, 7), M.bone, 'tail_blade', [0, 0.42, 0.06], [-0.35, 0, 0]);
}

function tank(THREE, c, root) {
  const { M, add, grp, ribStack, spur, limb } = c;
  // "Brood Hulk" — 2.6 m. The swollen abdomen is the HP readout: it splits and brightens as it takes damage.
  const torso = grp(root, 'torso', [0, 1.5, 0]);
  add(torso, new THREE.SphereGeometry(0.55, 30, 22), M.chitin, 'torso_shell', [0, 0, 0], [0, 0, 0], [1.15, 1, 0.8]);
  ribStack(torso, 'chest_band', M.bone, { count: 4, from: -0.4, to: 0.3, r0: 0.5, r1: 0.42, tube: 0.05, axis: 'y' });
  add(torso, new THREE.SphereGeometry(0.46, 28, 20), M.membrane, 'brood_abdomen', [0, -0.42, 0.16], [0, 0, 0], [1, 0.9, 1]);
  add(torso, new THREE.SphereGeometry(0.24, 24, 18), M.glow, 'brood_core', [0, -0.42, 0.16]);
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    add(torso, new THREE.BoxGeometry(0.05, 0.34, 0.05), M.bone, `abdomen_seam_${i + 1}`,
      [Math.cos(a) * 0.4, -0.42, 0.16 + Math.sin(a) * 0.32], [0, -a, 0]);
  }
  [-1, 1].forEach((s) => {
    add(torso, new THREE.SphereGeometry(0.3, 24, 18), M.chitin, `pauldron_${s > 0 ? 'r' : 'l'}`, [s * 0.55, 0.3, 0], [0, 0, 0], [1, 0.7, 1.1]);
    for (let i = 0; i < 3; i++) spur(torso, `pauldron_spur_${s > 0 ? 'r' : 'l'}_${i + 1}`, M.bone, [s * 0.62, 0.42, -0.2 + i * 0.2], [0, 0, s * -0.9], 0.05, 0.3);
  });

  const head = grp(root, 'head', [0, 2.0, -0.24], [0.2, 0, 0]);
  add(head, new THREE.SphereGeometry(0.2, 24, 18), M.chitin, 'skull_plate', [0, 0, 0], [0, 0, 0], [1.2, 0.8, 1]);
  add(head, new THREE.BoxGeometry(0.26, 0.09, 0.2), M.bone, 'mandible_plate', [0, -0.12, -0.12], [0.2, 0, 0]);
  add(head, new THREE.SphereGeometry(0.055, 18, 14), M.glow, 'eye_cluster_l', [-0.09, 0.03, -0.15]);
  add(head, new THREE.SphereGeometry(0.055, 18, 14), M.glow, 'eye_cluster_r', [0.09, 0.03, -0.15]);

  [-1, 1].forEach((s) => {
    const arm = grp(root, `arm_${s > 0 ? 'r' : 'l'}`, [s * 0.62, 1.72, 0], [0.3, 0, s * 0.25]);
    add(arm, new THREE.CapsuleGeometry(0.16, 0.5, 5, 18), M.chitin, `upper_arm_${s > 0 ? 'r' : 'l'}`, [0, -0.28, 0]);
    add(arm, new THREE.SphereGeometry(0.19, 20, 16), M.chitin, `elbow_${s > 0 ? 'r' : 'l'}`, [0, -0.58, 0]);
    const fore = grp(arm, `forearm_${s > 0 ? 'r' : 'l'}`, [0, -0.58, 0], [-0.45, 0, 0]);
    add(fore, new THREE.CapsuleGeometry(0.17, 0.42, 5, 18), M.chitin, `forearm_shell_${s > 0 ? 'r' : 'l'}`, [0, -0.24, 0]);
    add(fore, new THREE.SphereGeometry(0.26, 22, 16), M.bone, `slam_fist_${s > 0 ? 'r' : 'l'}`, [0, -0.55, 0], [0, 0, 0], [1, 0.85, 1]);
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * Math.PI * 2;
      spur(fore, `fist_knuckle_${s > 0 ? 'r' : 'l'}_${i + 1}`, M.bone, [Math.cos(a) * 0.2, -0.62, Math.sin(a) * 0.2], [Math.PI, 0, 0], 0.055, 0.18);
    }
    add(fore, new THREE.BoxGeometry(0.06, 0.3, 0.05), M.glow, `forearm_seam_${s > 0 ? 'r' : 'l'}`, [s * 0.16, -0.24, 0]);
  });

  limb(root, 'leg_l', M.chitin, { at: [-0.32, 1.14, 0.02], upper: 0.5, lower: 0.5, r: 0.17, a1: 0.16, a2: -0.34, claw: 0.2, spread: 0.1 });
  limb(root, 'leg_r', M.chitin, { at: [0.32, 1.14, 0.02], upper: 0.5, lower: 0.5, r: 0.17, a1: 0.16, a2: -0.34, claw: 0.2, spread: -0.1 });
}

function sniper(THREE, c, root) {
  const { M, add, grp, ribStack, spur, limb } = c;
  // "Ovipositor Stalk" — 2.4 m, almost no mass. The barrel-limb unfolds only during the telegraph.
  const thorax = grp(root, 'thorax', [0, 1.62, 0.04], [0.35, 0, 0]);
  add(thorax, new THREE.CapsuleGeometry(0.15, 0.34, 5, 20), M.chitin, 'thorax_shell', [0, 0, 0], [Math.PI / 2, 0, 0]);
  ribStack(thorax, 'thorax_rib', M.bone, { count: 4, from: -0.2, to: 0.2, r0: 0.155, r1: 0.14, tube: 0.02 });
  add(thorax, new THREE.SphereGeometry(0.11, 22, 16), M.membrane, 'venom_sac', [0, -0.1, 0.14], [0, 0, 0], [1, 0.85, 1.2]);
  for (let i = 0; i < 3; i++) spur(thorax, `dorsal_spur_${i + 1}`, M.bone, [0, 0.16, -0.1 + i * 0.14], [-0.5, 0, 0], 0.026, 0.22);

  const head = grp(root, 'head', [0, 1.86, -0.16], [0.15, 0, 0]);
  add(head, new THREE.SphereGeometry(0.11, 22, 16), M.chitin, 'head_shell', [0, 0, 0], [0, 0, 0], [0.9, 1, 1.2]);
  add(head, new THREE.SphereGeometry(0.075, 22, 16), M.glow, 'ranging_eye', [0, 0.01, -0.09], [0, 0, 0], [1, 1, 0.6]);
  add(head, new THREE.TorusGeometry(0.082, 0.016, 12, 24), M.bone, 'eye_hood', [0, 0.01, -0.09], [0, 0, 0]);

  // the long barrel-limb: three telescoping segments, held forward at eye height
  const bar = grp(root, 'ovipositor_limb', [0.16, 1.6, -0.16], [0.06, -0.05, 0]);
  add(bar, new THREE.CapsuleGeometry(0.075, 0.3, 4, 16), M.chitin, 'limb_root', [0, 0, 0.02], [Math.PI / 2, 0, 0]);
  add(bar, new THREE.CylinderGeometry(0.05, 0.062, 0.5, 18), M.chitin, 'limb_mid', [0, -0.01, -0.36], [Math.PI / 2, 0, 0]);
  add(bar, new THREE.CylinderGeometry(0.03, 0.048, 0.52, 16), M.bone, 'limb_tip', [0, -0.02, -0.86], [Math.PI / 2, 0, 0]);
  ribStack(bar, 'limb_ring', M.bone, { count: 6, from: -0.15, to: -0.6, r0: 0.058, r1: 0.048, tube: 0.012 });
  add(bar, new THREE.BoxGeometry(0.012, 0.03, 0.6), M.glow, 'charge_vein', [0, 0.052, -0.4]);
  add(bar, new THREE.SphereGeometry(0.026, 18, 14), M.glow, 'aperture_gland', [0, -0.02, -1.11]);
  for (let i = 0; i < 3; i++) {
    const a = (i / 3) * Math.PI * 2;
    add(bar, new THREE.ConeGeometry(0.014, 0.1, 5), M.bone, `aperture_barb_${i + 1}`,
      [Math.cos(a) * 0.03, -0.02 + Math.sin(a) * 0.03, -1.08], [-Math.PI / 2 + 0.1, 0, a]);
  }
  // support limb bracing the barrel
  add(root, new THREE.CapsuleGeometry(0.045, 0.34, 4, 14), M.chitin, 'brace_arm', [-0.14, 1.5, -0.34], [0.9, 0.3, 0]);

  limb(root, 'stilt_l', M.chitin, { at: [-0.17, 1.5, 0.1], upper: 0.72, lower: 0.72, r: 0.058, a1: -0.3, a2: 0.62, claw: 0.14, spread: 0.14 });
  limb(root, 'stilt_r', M.chitin, { at: [0.17, 1.5, 0.1], upper: 0.72, lower: 0.72, r: 0.058, a1: -0.24, a2: 0.5, claw: 0.14, spread: -0.14 });
  limb(root, 'stilt_rear', M.chitin, { at: [0, 1.52, 0.3], upper: 0.66, lower: 0.7, r: 0.05, a1: 0.5, a2: -0.8, claw: 0.12 });
}

function shooter(THREE, c, root) {
  const { M, add, grp, ribStack, limb } = c;
  // "Spore Marksman" — grafted host, one arm fused into a bio-rifle. 1.8 m.
  const torso = grp(root, 'torso', [0, 1.05, 0]);
  add(torso, new THREE.CapsuleGeometry(0.19, 0.5, 5, 18), M.chitin, 'torso_shell', [0, 0, 0]);
  add(torso, new THREE.SphereGeometry(0.15, 20, 16), M.membrane, 'chest_sac', [0, 0.1, 0.13], [0, 0, 0], [1, 0.9, 0.7]);
  add(torso, new THREE.SphereGeometry(0.07, 16, 12), M.glow, 'chest_core', [0, 0.1, 0.16]);
  ribStack(torso, 'torso_band', M.bone, { count: 3, from: -0.22, to: 0.22, r0: 0.2, r1: 0.18, tube: 0.02, axis: 'y' });

  const head = grp(root, 'head', [0, 1.68, 0.02]);
  add(head, new THREE.SphereGeometry(0.13, 20, 16), M.chitin, 'skull_plate', [0, 0, 0], [0, 0, 0], [0.95, 1, 1]);
  add(head, new THREE.BoxGeometry(0.2, 0.045, 0.05), M.glow, 'visor_band', [0, 0, -0.12]);
  const antenna = grp(head, 'antenna', [0.05, 0.13, 0], [0.15, 0, 0]);
  add(antenna, new THREE.CylinderGeometry(0.012, 0.018, 0.24, 8), M.bone, 'antenna_stalk', [0, 0.12, 0]);
  add(antenna, new THREE.SphereGeometry(0.026, 14, 10), M.glow, 'antenna_gland', [0, 0.25, 0]);

  const gunArm = grp(root, 'gun_arm', [0.24, 1.2, -0.05], [0.25, 0, -0.1]);
  add(gunArm, new THREE.CapsuleGeometry(0.075, 0.32, 4, 14), M.chitin, 'gun_upper', [0, -0.16, 0]);
  add(gunArm, new THREE.CylinderGeometry(0.045, 0.06, 0.4, 16), M.chitin, 'gun_barrel', [0, -0.36, -0.18], [Math.PI / 2 - 0.2, 0, 0]);
  ribStack(gunArm, 'gun_rib', M.bone, { count: 4, from: -0.28, to: -0.44, r0: 0.05, r1: 0.062, tube: 0.009 });
  add(gunArm, new THREE.SphereGeometry(0.032, 16, 12), M.glow, 'muzzle_gland', [0, -0.4, -0.4]);

  limb(root, 'off_arm', M.chitin, { at: [-0.24, 1.2, 0], upper: 0.3, lower: 0.28, r: 0.06, a1: 0.15, a2: -0.3, claw: 0.08 });
  limb(root, 'leg_l', M.chitin, { at: [-0.12, 0.68, 0], upper: 0.34, lower: 0.34, r: 0.075, a1: 0.05, a2: -0.1, claw: 0.1 });
  limb(root, 'leg_r', M.chitin, { at: [0.12, 0.68, 0], upper: 0.34, lower: 0.34, r: 0.075, a1: 0.05, a2: -0.1, claw: 0.1 });
}

function dasher(THREE, c, root) {
  const { M, add, grp, ribStack, limb } = c;
  // "Blink Fang" — low, finned quadruped built for one burst-speed lunge. 1.5 m.
  const torso = grp(root, 'torso', [0, 0.5, 0]);
  add(torso, new THREE.CapsuleGeometry(0.16, 0.55, 5, 18), M.chitin, 'torso_shell', [0, 0, 0], [Math.PI / 2, 0, 0], [1, 1, 0.85]);
  add(torso, new THREE.SphereGeometry(0.1, 18, 14), M.membrane, 'flank_sac', [0, -0.02, 0.12], [0, 0, 0], [1, 0.7, 1.2]);
  ribStack(torso, 'dorsal_rib', M.bone, { count: 4, from: -0.24, to: 0.22, r0: 0.17, r1: 0.15, tube: 0.018 });
  [-1, 1].forEach((s) => {
    add(torso, new THREE.BoxGeometry(0.02, 0.3, 0.32), M.bone, `fin_${s > 0 ? 'r' : 'l'}`, [s * 0.14, 0.16, 0.05], [0, 0, s * 0.35]);
    add(torso, new THREE.BoxGeometry(0.008, 0.2, 0.24), M.glow, `fin_vein_${s > 0 ? 'r' : 'l'}`, [s * 0.15, 0.16, 0.05], [0, 0, s * 0.35]);
  });

  const head = grp(root, 'head', [0, 0.52, -0.42], [0.1, 0, 0]);
  add(head, new THREE.SphereGeometry(0.1, 18, 14), M.chitin, 'skull_plate', [0, 0, 0], [0, 0, 0], [1, 0.85, 1.3]);
  add(head, new THREE.SphereGeometry(0.032, 14, 10), M.glow, 'eye_l', [-0.05, 0.02, -0.08]);
  add(head, new THREE.SphereGeometry(0.032, 14, 10), M.glow, 'eye_r', [0.05, 0.02, -0.08]);

  [-1, 1].forEach((s) => {
    const arm = grp(root, `blade_limb_${s > 0 ? 'r' : 'l'}`, [s * 0.16, 0.62, -0.28], [0.2, 0, s * 0.15]);
    add(arm, new THREE.CapsuleGeometry(0.045, 0.26, 4, 12), M.chitin, `blade_upper_${s > 0 ? 'r' : 'l'}`, [0, -0.14, 0]);
    add(arm, new THREE.ConeGeometry(0.038, 0.4, 6), M.bone, `blade_edge_${s > 0 ? 'r' : 'l'}`, [0, -0.34, -0.06], [Math.PI, 0, 0]);
    add(arm, new THREE.BoxGeometry(0.01, 0.02, 0.3), M.glow, `blade_vein_${s > 0 ? 'r' : 'l'}`, [0, -0.3, -0.02]);
  });

  limb(root, 'hindleg_l', M.chitin, { at: [-0.13, 0.44, 0.24], upper: 0.28, lower: 0.26, r: 0.06, a1: -0.4, a2: 0.85, spread: 0.1 });
  limb(root, 'hindleg_r', M.chitin, { at: [0.13, 0.44, 0.24], upper: 0.28, lower: 0.26, r: 0.06, a1: -0.25, a2: 0.65, spread: -0.1 });
}

function exploder(THREE, c, root) {
  const { M, add, grp, spur } = c;
  // "Swelling Spore" — visibly inflates as its fuse core brightens toward detonation. 1.1 m.
  const body = grp(root, 'spore_body', [0, 0.5, 0]);
  add(body, new THREE.SphereGeometry(0.42, 26, 20), M.membrane, 'spore_membrane', [0, 0, 0], [0, 0, 0], [1, 1.05, 1]);
  add(body, new THREE.SphereGeometry(0.22, 22, 16), M.glow, 'fuse_core', [0, 0.02, 0]);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    const y = (i % 2 === 0) ? 0.14 : -0.1;
    spur(body, `spike_${i + 1}`, M.bone, [Math.cos(a) * 0.4, y, Math.sin(a) * 0.4], [0.5 * Math.sin(a), 0, -0.5 * Math.cos(a)], 0.045, 0.28);
  }
  add(body, new THREE.SphereGeometry(0.06, 16, 12), M.glow, 'fuse_gland', [0, 0.44, 0]);

  const ring = grp(root, 'blast_ring', [0, 0.03, 0]);
  add(ring, new THREE.TorusGeometry(0.46, 0.03, 10, 28), M.glow, 'ring_band', [0, 0, 0], [Math.PI / 2, 0, 0]);
}

function support(THREE, c, root) {
  const { M, add, grp, ribStack, spur } = c;
  // "Choir Spore" — small hovering colony; three motes pulse in sync when it buffs broodkin. 1.5 m.
  const core = grp(root, 'core_body', [0, 1.0, 0]);
  add(core, new THREE.SphereGeometry(0.22, 24, 18), M.chitin, 'core_shell', [0, 0, 0], [0, 0, 0], [1, 0.9, 1]);
  add(core, new THREE.SphereGeometry(0.13, 20, 16), M.glow, 'core_gland', [0, 0, 0.05]);
  ribStack(core, 'core_band', M.bone, { count: 3, from: -0.16, to: 0.14, r0: 0.23, r1: 0.2, tube: 0.02, axis: 'y' });

  for (let i = 0; i < 3; i++) {
    const a = (i / 3) * Math.PI * 2;
    const mote = grp(root, `choir_mote_${i + 1}`, [Math.cos(a) * 0.34, 1.15 + Math.sin(a * 2) * 0.08, Math.sin(a) * 0.34]);
    add(mote, new THREE.SphereGeometry(0.09, 18, 14), M.membrane, `mote_sac_${i + 1}`, [0, 0, 0]);
    add(mote, new THREE.SphereGeometry(0.045, 14, 10), M.glow, `mote_core_${i + 1}`, [0, 0, 0]);
  }

  for (let i = 0; i < 4; i++) spur(core, `crest_spur_${i + 1}`, M.bone, [(i - 1.5) * 0.09, 0.24, -0.02], [-0.4, 0, (i - 1.5) * 0.25], 0.03, 0.22);

  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2;
    const t = grp(root, `tendril_${i + 1}`, [Math.cos(a) * 0.18, 0.82, Math.sin(a) * 0.16]);
    add(t, new THREE.CapsuleGeometry(0.035, 0.3, 4, 10), M.chitin, `tendril_shaft_${i + 1}`, [0, -0.15, 0]);
    add(t, new THREE.SphereGeometry(0.025, 12, 10), M.glow, `tendril_tip_${i + 1}`, [0, -0.32, 0]);
  }
}

function displacer(THREE, c, root) {
  const { M, add, grp, spur } = c;
  // "Phase Wraith" — a hovering cloak that flickers and re-anchors at both ends of its blink. 1.3 m.
  const torso = grp(root, 'torso', [0, 0.75, 0]);
  add(torso, new THREE.CapsuleGeometry(0.14, 0.4, 5, 16), M.chitin, 'torso_shell', [0, 0, 0]);
  add(torso, new THREE.SphereGeometry(0.19, 22, 16), M.membrane, 'phase_cloak', [0, 0.05, 0], [0, 0, 0], [1.3, 1.4, 1]);
  add(torso, new THREE.SphereGeometry(0.08, 18, 14), M.glow, 'phase_core', [0, 0.08, 0.05]);

  const head = grp(root, 'head', [0, 1.15, 0]);
  add(head, new THREE.SphereGeometry(0.1, 18, 14), M.chitin, 'skull_plate', [0, 0, 0]);
  add(head, new THREE.SphereGeometry(0.035, 14, 10), M.glow, 'command_eye', [0, 0, -0.09]);
  for (let i = 0; i < 5; i++) spur(head, `crown_spur_${i + 1}`, M.bone, [(i - 2) * 0.05, 0.1, 0.01], [-0.4, 0, (i - 2) * 0.3], 0.02, 0.16);

  [-1, 1].forEach((s) => {
    const arm = grp(root, `blade_arm_${s > 0 ? 'r' : 'l'}`, [s * 0.17, 0.85, -0.05], [0.25, 0, s * 0.2]);
    add(arm, new THREE.CapsuleGeometry(0.04, 0.26, 4, 12), M.chitin, `blade_arm_upper_${s > 0 ? 'r' : 'l'}`, [0, -0.14, 0]);
    add(arm, new THREE.ConeGeometry(0.032, 0.36, 6), M.bone, `blade_edge_${s > 0 ? 'r' : 'l'}`, [0, -0.32, -0.05], [Math.PI, 0, 0]);
    add(arm, new THREE.BoxGeometry(0.008, 0.018, 0.26), M.glow, `blade_vein_${s > 0 ? 'r' : 'l'}`, [0, -0.28, -0.02]);
  });

  add(root, new THREE.ConeGeometry(0.16, 0.6, 12, 1, true), M.membrane, 'cloak_hem', [0, 0.3, 0], [Math.PI, 0, 0]);
}

/* ============================ bosses ============================ */

function titan(THREE, c, root) {
  const { M, add, grp, ribStack, spur, limb } = c;
  // "Hive-Colossus" — 6.4 m. Phase 2 is written into the model: the ribcage plates peel open.
  const torso = grp(root, 'torso', [0, 3.9, 0]);
  add(torso, new THREE.SphereGeometry(1.15, 32, 24), M.chitin, 'torso_shell', [0, 0, 0], [0, 0, 0], [1.15, 1.1, 0.85]);
  // peeled ribcage plates revealing the brood cavity
  for (let i = 0; i < 5; i++) {
    const t = i / 4;
    [-1, 1].forEach((s) => {
      add(torso, new THREE.BoxGeometry(0.34, 0.16, 0.85), M.bone, `rib_plate_${s > 0 ? 'r' : 'l'}_${i + 1}`,
        [s * (0.42 + t * 0.16), 0.55 - t * 1.0, -0.5], [0, s * (0.25 + t * 0.2), s * (0.5 - t * 0.25)]);
    });
  }
  add(torso, new THREE.SphereGeometry(0.7, 28, 20), M.membrane, 'brood_cavity', [0, -0.1, -0.5], [0, 0, 0], [1, 1.15, 0.7]);
  add(torso, new THREE.SphereGeometry(0.42, 26, 20), M.glow, 'phase_core', [0, -0.1, -0.52]);
  for (let i = 0; i < 4; i++) {
    add(torso, new THREE.SphereGeometry(0.16, 18, 14), M.glow, `add_pod_${i + 1}`,
      [(i - 1.5) * 0.3, -0.55 + (i % 2) * 0.3, -0.75]);
  }
  ribStack(torso, 'spinal_band', M.bone, { count: 5, from: -0.9, to: 0.8, r0: 0.9, r1: 0.75, tube: 0.09, axis: 'y' });

  const head = grp(root, 'head', [0, 5.2, -0.35], [0.25, 0, 0]);
  add(head, new THREE.SphereGeometry(0.46, 26, 20), M.chitin, 'skull_shell', [0, 0, 0], [0, 0, 0], [1.1, 0.9, 1.1]);
  add(head, new THREE.BoxGeometry(0.6, 0.2, 0.44), M.bone, 'jaw_plate', [0, -0.28, -0.24], [0.22, 0, 0]);
  for (let i = 0; i < 7; i++) {
    const a = -0.9 + i * 0.3;
    spur(head, `crown_spur_${i + 1}`, M.bone, [Math.sin(a) * 0.42, 0.34, -0.05 - Math.cos(a) * 0.1], [-0.4, 0, Math.sin(a) * 1.1], 0.08, 0.62);
  }
  add(head, new THREE.SphereGeometry(0.13, 18, 14), M.glow, 'eye_l', [-0.2, 0.02, -0.34]);
  add(head, new THREE.SphereGeometry(0.13, 18, 14), M.glow, 'eye_r', [0.2, 0.02, -0.34]);

  [-1, 1].forEach((s) => {
    add(torso, new THREE.SphereGeometry(0.6, 24, 18), M.chitin, `pauldron_${s > 0 ? 'r' : 'l'}`, [s * 1.15, 0.7, -0.05], [0, 0, 0], [1, 0.75, 1.05]);
    for (let i = 0; i < 4; i++) spur(torso, `pauldron_spur_${s > 0 ? 'r' : 'l'}_${i + 1}`, M.bone, [s * 1.3, 0.95, -0.5 + i * 0.32], [0, 0, s * -1.0], 0.1, 0.68);
    const arm = grp(root, `arm_${s > 0 ? 'r' : 'l'}`, [s * 1.3, 4.5, -0.05], [0.2, 0, s * 0.2]);
    add(arm, new THREE.CapsuleGeometry(0.33, 1.0, 6, 20), M.chitin, `upper_arm_${s > 0 ? 'r' : 'l'}`, [0, -0.55, 0]);
    add(arm, new THREE.SphereGeometry(0.38, 22, 16), M.chitin, `elbow_${s > 0 ? 'r' : 'l'}`, [0, -1.15, 0]);
    const fore = grp(arm, `forearm_${s > 0 ? 'r' : 'l'}`, [0, -1.15, 0], [-0.5, 0, 0]);
    add(fore, new THREE.CapsuleGeometry(0.36, 0.9, 6, 20), M.chitin, `forearm_shell_${s > 0 ? 'r' : 'l'}`, [0, -0.5, 0]);
    add(fore, new THREE.BoxGeometry(0.12, 0.7, 0.1), M.glow, `forearm_seam_${s > 0 ? 'r' : 'l'}`, [s * 0.34, -0.5, 0]);
    add(fore, new THREE.SphereGeometry(0.52, 24, 18), M.bone, `slam_fist_${s > 0 ? 'r' : 'l'}`, [0, -1.15, 0], [0, 0, 0], [1, 0.8, 1]);
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * Math.PI * 2;
      spur(fore, `fist_spike_${s > 0 ? 'r' : 'l'}_${i + 1}`, M.bone, [Math.cos(a) * 0.4, -1.28, Math.sin(a) * 0.4], [Math.PI, 0, 0], 0.1, 0.36);
    }
  });

  limb(root, 'leg_l', M.chitin, { at: [-0.6, 2.95, 0.05], upper: 1.1, lower: 1.05, r: 0.36, a1: 0.14, a2: -0.3, claw: 0.44, spread: 0.1 });
  limb(root, 'leg_r', M.chitin, { at: [0.6, 2.95, 0.05], upper: 1.1, lower: 1.05, r: 0.36, a1: 0.14, a2: -0.3, claw: 0.44, spread: -0.1 });
  const tail = grp(root, 'anchor_tail', [0, 3.6, 0.85], [0.85, 0, 0]);
  add(tail, new THREE.CapsuleGeometry(0.24, 1.1, 5, 18), M.chitin, 'tail_base', [0, 0.6, 0]);
  add(tail, new THREE.ConeGeometry(0.2, 1.0, 7), M.bone, 'tail_anchor', [0, 1.5, 0.2], [-0.3, 0, 0]);
}

function warden(THREE, c, root) {
  const { M, add, grp, ribStack, spur } = c;
  // "Brood Warden" — 3.2 m, legless, hovers. The shell irises open during the shield pulse: that IS the window.
  const core = grp(root, 'core_body', [0, 1.9, 0]);
  add(core, new THREE.SphereGeometry(0.62, 30, 22), M.chitin, 'torso_shell', [0, 0, 0], [0, 0, 0], [1, 1.2, 0.9]);
  add(core, new THREE.SphereGeometry(0.4, 26, 20), M.membrane, 'shield_gland', [0, -0.1, -0.16], [0, 0, 0], [1, 1, 0.8]);
  add(core, new THREE.SphereGeometry(0.24, 24, 18), M.glow, 'warden_core', [0, -0.1, -0.2]);
  ribStack(core, 'torso_band', M.bone, { count: 4, from: -0.5, to: 0.45, r0: 0.5, r1: 0.44, tube: 0.055, axis: 'y' });

  // iris shell: 6 hinged plates around the core
  const iris = grp(root, 'iris_shell', [0, 1.85, -0.1]);
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    const g = grp(iris, `iris_plate_${i + 1}`, [Math.cos(a) * 0.62, Math.sin(a) * 0.62, 0], [0, 0, a]);
    add(g, new THREE.BoxGeometry(0.16, 0.42, 0.5), M.bone, `iris_plate_shell_${i + 1}`, [0.06, 0, 0], [0, 0.3, 0]);
    add(g, new THREE.BoxGeometry(0.04, 0.3, 0.06), M.glow, `iris_seam_${i + 1}`, [-0.02, 0, -0.2]);
  }

  const head = grp(root, 'head', [0, 2.5, -0.2], [0.2, 0, 0]);
  add(head, new THREE.SphereGeometry(0.26, 24, 18), M.chitin, 'head_shell', [0, 0, 0], [0, 0, 0], [1.1, 0.85, 1]);
  add(head, new THREE.SphereGeometry(0.1, 20, 14), M.glow, 'command_eye', [0, 0, -0.22]);
  for (let i = 0; i < 5; i++) spur(head, `crest_spur_${i + 1}`, M.bone, [(i - 2) * 0.12, 0.2, 0.04], [-0.5, 0, (i - 2) * 0.35], 0.045, 0.34);

  // summon sacs on the back
  for (let i = 0; i < 3; i++) {
    add(core, new THREE.SphereGeometry(0.22, 20, 16), M.membrane, `summon_sac_${i + 1}`, [(i - 1) * 0.34, 0.3 - Math.abs(i - 1) * 0.16, 0.5]);
    add(core, new THREE.SphereGeometry(0.09, 16, 12), M.glow, `summon_sac_core_${i + 1}`, [(i - 1) * 0.34, 0.3 - Math.abs(i - 1) * 0.16, 0.5]);
  }
  // arms
  [-1, 1].forEach((s) => {
    const arm = grp(root, `arm_${s > 0 ? 'r' : 'l'}`, [s * 0.62, 2.15, -0.05], [0.4, 0, s * 0.5]);
    add(arm, new THREE.CapsuleGeometry(0.11, 0.5, 4, 16), M.chitin, `upper_arm_${s > 0 ? 'r' : 'l'}`, [0, -0.3, 0]);
    const fore = grp(arm, `forearm_${s > 0 ? 'r' : 'l'}`, [0, -0.62, 0], [-0.8, 0, 0]);
    add(fore, new THREE.CapsuleGeometry(0.09, 0.5, 4, 16), M.chitin, `forearm_${s > 0 ? 'r' : 'l'}`, [0, -0.28, 0]);
    for (let i = 0; i < 3; i++) {
      add(fore, new THREE.ConeGeometry(0.03, 0.26, 5), M.bone, `summon_claw_${s > 0 ? 'r' : 'l'}_${i + 1}`,
        [(i - 1) * 0.05, -0.62, 0.02], [Math.PI - 0.2, 0, (i - 1) * 0.4]);
    }
  });
  // hovering tendrils
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2;
    const t = grp(root, `tendril_${i + 1}`, [Math.cos(a) * 0.3, 1.4, Math.sin(a) * 0.24], [0.2 * Math.cos(a), 0, 0.2 * Math.sin(a)]);
    add(t, new THREE.CapsuleGeometry(0.06, 0.5, 4, 12), M.chitin, `tendril_upper_${i + 1}`, [0, -0.28, 0]);
    add(t, new THREE.CapsuleGeometry(0.04, 0.44, 4, 12), M.membrane, `tendril_lower_${i + 1}`, [Math.cos(a) * 0.1, -0.76, Math.sin(a) * 0.08], [0.25 * Math.cos(a), 0, 0.25 * Math.sin(a)]);
    add(t, new THREE.SphereGeometry(0.045, 14, 10), M.glow, `tendril_tip_${i + 1}`, [Math.cos(a) * 0.2, -1.0, Math.sin(a) * 0.16]);
  }
}

/* ============================ world ============================ */

function obstacles(THREE, c, root) {
  const { M, add, grp, ribStack, spur } = c;
  // Hive growth: the same four cover archetypes, grown instead of built.
  // Rib-arch pillar
  const pil = grp(root, 'pillar_rib_arch', [-2.1, 0, 0.2]);
  add(pil, new THREE.CylinderGeometry(0.32, 0.46, 3.0, 22), M.chitin, 'pillar_trunk', [0, 1.5, 0]);
  ribStack(pil, 'pillar_rib', M.bone, { count: 7, from: 0.3, to: 2.8, r0: 0.46, r1: 0.3, tube: 0.06, axis: 'y' });
  add(pil, new THREE.BoxGeometry(0.1, 2.2, 0.1), M.glow, 'pillar_vein', [0.34, 1.5, 0], [0, 0, 0.04]);
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2;
    spur(pil, `pillar_crown_spur_${i + 1}`, M.bone, [Math.cos(a) * 0.26, 3.05, Math.sin(a) * 0.26], [0.3 * Math.sin(a), 0, -0.3 * Math.cos(a)], 0.09, 0.6);
  }
  add(pil, new THREE.SphereGeometry(0.55, 22, 16), M.chitin, 'pillar_root_mass', [0, 0.12, 0], [0, 0, 0], [1, 0.35, 1]);

  // Egg-sac cluster (crate cluster)
  const eggs = grp(root, 'eggsac_cluster', [-0.5, 0, -0.9]);
  const sacs = [[0, 0.42, 0, 0.42], [0.62, 0.34, 0.2, 0.34], [-0.5, 0.3, 0.42, 0.3], [0.2, 0.95, 0.16, 0.3]];
  sacs.forEach(([x, y, z, r], i) => {
    add(eggs, new THREE.SphereGeometry(r, 22, 16), M.membrane, `eggsac_${i + 1}`, [x, y, z], [0, 0, 0], [1, 1.25, 1]);
    add(eggs, new THREE.SphereGeometry(r * 0.42, 16, 12), M.glow, `eggsac_core_${i + 1}`, [x, y, z]);
    ribStack(grp(eggs, `eggsac_bands_${i + 1}`, [x, y, z]), `eggsac_band_${i + 1}`, M.bone, { count: 3, from: -r * 0.7, to: r * 0.7, r0: r * 0.8, r1: r * 0.8, tube: r * 0.09, axis: 'y' });
  });

  // Membrane wall (breakable cover) — visibly thin, already split
  const wall = grp(root, 'breakable_membrane_wall', [1.3, 0, -0.4], [0, -0.25, 0]);
  add(wall, new THREE.BoxGeometry(2.0, 1.9, 0.09), M.membrane, 'membrane_pane', [0, 0.98, 0]);
  add(wall, new THREE.BoxGeometry(2.1, 0.14, 0.16), M.bone, 'wall_lintel', [0, 1.95, 0]);
  [-1, 1].forEach((s) => add(wall, new THREE.CylinderGeometry(0.09, 0.12, 2.0, 14), M.chitin, `wall_stanchion_${s > 0 ? 'r' : 'l'}`, [s * 1.0, 1.0, 0]));
  for (let i = 0; i < 5; i++) {
    add(wall, new THREE.BoxGeometry(0.035, 1.3, 0.11), M.glow, `wall_fissure_${i + 1}`, [-0.7 + i * 0.36, 0.95 + (i % 2) * 0.18, 0], [0, 0, 0.2 - i * 0.09]);
  }

  // Carapace ramp
  const ramp = grp(root, 'carapace_ramp', [2.9, 0, 0.7], [0, 0.35, 0]);
  add(ramp, new THREE.BoxGeometry(1.5, 0.16, 2.6), M.chitin, 'ramp_deck', [0, 0.62, 0], [-0.42, 0, 0]);
  ribStack(grp(ramp, 'ramp_rib_grp', [0, 0.62, 0], [-0.42, 0, 0]), 'ramp_rib', M.bone, { count: 6, from: -1.1, to: 1.1, r0: 0.76, r1: 0.76, tube: 0.05 });
  add(ramp, new THREE.BoxGeometry(1.5, 0.06, 2.6), M.glow, 'ramp_seam', [0, 0.57, 0], [-0.42, 0, 0]);
  [-1, 1].forEach((s) => add(ramp, new THREE.CylinderGeometry(0.13, 0.2, 1.1, 14), M.chitin, `ramp_root_${s > 0 ? 'r' : 'l'}`, [s * 0.6, 0.5, 0.95], [0.2, 0, 0]));
}

const BUILDERS = { pulse_rifle: pulseRifle, scatter_cannon: scatterCannon, beam_emitter: beamEmitter, chaser, tank, sniper, shooter, dasher, exploder, support, displacer, titan, warden, obstacles };

export function buildEntity(THREE, key = 'pulse_rifle') {
  const c = ctx(THREE);
  const root = new THREE.Group();
  root.name = key;
  (BUILDERS[key] || pulseRifle)(THREE, c, root);
  root.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
  const box = new THREE.Box3().setFromObject(root);
  const ctr = box.getCenter(new THREE.Vector3());
  root.children.forEach((ch) => {
    ch.position.x -= ctr.x;
    ch.position.y -= box.min.y;
    ch.position.z -= ctr.z;
  });
  let meshes = 0;
  root.traverse((o) => { if (o.isMesh) meshes++; });
  root.userData.meshes = meshes;
  root.userData.size = new THREE.Vector3().subVectors(box.max, box.min).toArray().map((v) => +v.toFixed(2));
  return root;
}
