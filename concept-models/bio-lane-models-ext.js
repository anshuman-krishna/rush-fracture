// Rush Fracture — "Grafted Brood" art lane, second set.
// Same five materials and part vocabulary as bio-lane-models.js: new weapons,
// enemies, bosses, the player host body, and arena props.
// Units: meters, y-up, forward is -Z, lowest point recentered to y=0.
// Empty groups named anchor_* mark attachment points the game reads by name.

import { BUILDERS, ENTITIES } from './bio-lane-models.js';

const HALF_PI = Math.PI / 2;
const side = (s) => (s > 0 ? 'r' : 'l');

// ring around the Z axis (a band around a barrel) or the Y axis (a belt)
function band(THREE, c, parent, name, mat, r, tube, pos, axis = 'z') {
  return c.add(parent, new THREE.TorusGeometry(r, tube, 8, 22), mat, name, pos, axis === 'y' ? [HALF_PI, 0, 0] : [0, 0, 0]);
}

// shared pistol grip so every weapon sits in the hand the same way
function grip(THREE, c, root, y = -0.11, z = 0.14) {
  const { M, add, grp } = c;
  const g = grp(root, 'grip_spine', [0, y, z], [-0.26, 0, 0]);
  add(g, new THREE.CapsuleGeometry(0.028, 0.11, 4, 16), M.chitin, 'grip_shaft', [0, 0, 0]);
  for (let i = 0; i < 3; i++) add(g, new THREE.SphereGeometry(0.02, 14, 10), M.bone, `knuckle_nub_${i + 1}`, [0, 0.04 - i * 0.04, -0.026]);
  add(root, new THREE.TorusGeometry(0.03, 0.008, 10, 20, Math.PI * 1.2), M.bone, 'trigger_hook', [0, y + 0.04, z - 0.065], [0, HALF_PI, -0.5]);
}

// a leg that splays sideways from the body: hip → knee → foot claw
function splayLeg(THREE, c, parent, name, mat, { at, upper, lower, r, out, lift, bend, yaw = 0 }) {
  const { M, add, grp } = c;
  const hip = grp(parent, name, at, [0, yaw, 0]);
  const up = grp(hip, `${name}_upper_grp`, [0, 0, 0], [0, 0, out]);
  add(up, new THREE.SphereGeometry(r * 1.3, 14, 10), mat, `${name}_hip`, [0, 0, 0]);
  add(up, new THREE.CapsuleGeometry(r, upper, 4, 12), mat, `${name}_upper`, [0, upper / 2, 0]);
  const knee = grp(up, `${name}_knee_grp`, [0, upper, 0], [0, 0, bend]);
  add(knee, new THREE.SphereGeometry(r * 1.25, 14, 10), mat, `${name}_knee`, [0, 0, 0]);
  add(knee, new THREE.CapsuleGeometry(r * 0.75, lower, 4, 12), mat, `${name}_lower`, [0, lower / 2, 0]);
  add(knee, new THREE.ConeGeometry(r * 0.8, r * 3.2, 6), M.bone, `${name}_claw`, [0, lower + r * 1.4, 0]);
  void lift;
  return hip;
}

/* ============================ weapons ============================ */

function railLance(THREE, c, root) {
  const { M, add, grp, spur } = c;
  // "Marrow Lance" — a hollowed femur grown into an accelerator. Four charge nodes light in sequence.
  const stock = grp(root, 'stock', [0, 0, 0.3]);
  add(stock, new THREE.CapsuleGeometry(0.05, 0.2, 4, 16), M.chitin, 'stock_shell', [0, 0, 0], [HALF_PI, 0, 0]);
  add(stock, new THREE.SphereGeometry(0.066, 20, 14), M.membrane, 'marrow_sac', [0, -0.035, -0.04], [0, 0, 0], [1, 0.9, 1.5]);
  spur(stock, 'cheek_spur', M.bone, [0, 0.05, 0.1], [-HALF_PI * 0.8, 0, 0], 0.03, 0.2);

  const rec = grp(root, 'receiver', [0, 0.01, 0.04]);
  add(rec, new THREE.SphereGeometry(0.072, 24, 18), M.chitin, 'receiver_shell', [0, 0, 0], [0, 0, 0], [1, 1, 2.3]);
  add(rec, new THREE.SphereGeometry(0.036, 18, 14), M.glow, 'charge_core', [0, 0.045, 0.02]);
  band(THREE, c, rec, 'receiver_band_1', M.bone, 0.074, 0.01, [0, 0, -0.08]);
  band(THREE, c, rec, 'receiver_band_2', M.bone, 0.07, 0.01, [0, 0, 0.08]);

  [-1, 1].forEach((s) => {
    add(root, new THREE.BoxGeometry(0.018, 0.052, 0.84), M.bone, `rail_${side(s)}`, [s * 0.036, 0.012, -0.5]);
    add(root, new THREE.BoxGeometry(0.006, 0.014, 0.78), M.glow, `rail_vein_${side(s)}`, [s * 0.025, 0.012, -0.5]);
    spur(root, `tip_fang_${side(s)}`, M.bone, [s * 0.036, 0.012, -0.96], [-HALF_PI, 0, 0], 0.014, 0.1);
  });
  for (let i = 0; i < 4; i++) {
    const z = -0.2 - i * 0.2;
    band(THREE, c, root, `rail_clamp_${i + 1}`, M.graft, 0.05, 0.011, [0, 0.012, z]);
    add(root, new THREE.SphereGeometry(0.018, 14, 10), M.glow, `charge_node_${i + 1}`, [0, 0.07, z]);
  }
  grip(THREE, c, root);
  grp(root, 'anchor_muzzle', [0, 0.012, -0.95]);
}

function sporeLauncher(THREE, c, root) {
  const { M, add, grp, spur } = c;
  // "Bile Mortar" — a stomach with a barrel. The sac underneath is the next round.
  const drum = grp(root, 'drum', [0, 0.03, 0.02]);
  add(drum, new THREE.SphereGeometry(0.12, 28, 20), M.chitin, 'drum_shell', [0, 0, 0], [0, 0, 0], [1, 1, 1.35]);
  add(drum, new THREE.SphereGeometry(0.085, 24, 18), M.membrane, 'bile_sac', [0, -0.085, 0.02], [0, 0, 0], [1, 0.9, 1.3]);
  add(drum, new THREE.SphereGeometry(0.045, 20, 14), M.glow, 'bile_core', [0, -0.09, 0.02]);
  for (let i = 0; i < 3; i++) band(THREE, c, drum, `drum_band_${i + 1}`, M.bone, 0.118 - Math.abs(i - 1) * 0.02, 0.012, [0, 0, -0.1 + i * 0.1]);

  const maw = grp(root, 'maw', [0, 0.03, -0.27]);
  add(maw, new THREE.CylinderGeometry(0.06, 0.088, 0.3, 22, 1, true), M.chitin, 'maw_tube', [0, 0, 0], [HALF_PI, 0, 0]);
  band(THREE, c, maw, 'maw_lip', M.bone, 0.088, 0.015, [0, 0, -0.15]);
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    spur(maw, `maw_tooth_${i + 1}`, M.bone, [Math.cos(a) * 0.08, Math.sin(a) * 0.08, -0.19], [-HALF_PI, 0, 0], 0.014, 0.08);
  }
  add(maw, new THREE.SphereGeometry(0.04, 16, 12), M.glow, 'maw_gland', [0, 0, -0.06]);
  spur(root, 'shoulder_brace', M.bone, [0, 0.07, 0.24], [-Math.PI * 0.42, 0, 0], 0.035, 0.22);
  grip(THREE, c, root, -0.12, 0.16);
  grp(root, 'anchor_muzzle', [0, 0.03, -0.44]);
}

function needler(THREE, c, root) {
  const { M, add, grp } = c;
  // "Needle Hive" — a comb of quills. Fired quills regrow from the rack on top.
  const hive = grp(root, 'hive', [0, 0.02, -0.04]);
  add(hive, new THREE.BoxGeometry(0.1, 0.085, 0.3), M.chitin, 'hive_block', [0, 0, 0]);
  add(hive, new THREE.SphereGeometry(0.058, 18, 14), M.chitin, 'hive_cap_rear', [0, 0, 0.15], [0, 0, 0], [0.9, 0.78, 1]);
  add(hive, new THREE.SphereGeometry(0.05, 18, 14), M.membrane, 'venom_bladder', [0, -0.055, 0.04], [0, 0, 0], [0.9, 0.8, 1.6]);
  [-1, 1].forEach((s) => add(hive, new THREE.BoxGeometry(0.006, 0.02, 0.24), M.glow, `venom_vein_${side(s)}`, [s * 0.052, -0.01, 0]));
  for (let row = 0; row < 4; row++) {
    for (let col = 0; col < 3; col++) {
      add(hive, new THREE.ConeGeometry(0.008, 0.09, 5), M.bone, `quill_${row * 3 + col + 1}`,
        [(col - 1) * 0.028, 0.075, 0.1 - row * 0.06], [-0.55, 0, 0]);
    }
  }
  const nose = grp(root, 'barrel_cluster', [0, 0.02, -0.27]);
  [[0, 0.018], [-0.02, -0.014], [0.02, -0.014]].forEach(([x, y], i) => {
    add(nose, new THREE.CylinderGeometry(0.011, 0.013, 0.17, 10), M.bone, `needle_tube_${i + 1}`, [x, y, 0], [HALF_PI, 0, 0]);
    add(nose, new THREE.SphereGeometry(0.008, 10, 8), M.glow, `tube_gland_${i + 1}`, [x, y, -0.085]);
  });
  band(THREE, c, nose, 'cluster_band', M.graft, 0.04, 0.008, [0, 0, 0.04]);
  grip(THREE, c, root, -0.1, 0.1);
  grp(root, 'anchor_muzzle', [0, 0.02, -0.37]);
}

function arcCaster(THREE, c, root) {
  const { M, add, grp } = c;
  // "Synapse Coil" — two nerve prongs; the charge arcs between them before it jumps.
  const body = grp(root, 'coil_body', [0, 0.01, 0.06]);
  add(body, new THREE.CapsuleGeometry(0.05, 0.2, 4, 18), M.chitin, 'body_shell', [0, 0, 0], [HALF_PI, 0, 0]);
  for (let i = 0; i < 6; i++) band(THREE, c, body, `coil_wrap_${i + 1}`, M.graft, 0.055, 0.007, [0, 0, -0.1 + i * 0.04]);
  add(body, new THREE.SphereGeometry(0.045, 18, 14), M.membrane, 'charge_sac', [0, -0.05, 0.05], [0, 0, 0], [1, 0.8, 1.4]);
  add(body, new THREE.SphereGeometry(0.032, 18, 14), M.glow, 'arc_core', [0, 0, -0.17]);

  [-1, 1].forEach((s) => {
    const prong = grp(root, `prong_${side(s)}`, [s * 0.055, 0.01, -0.12], [0, s * 0.07, 0]);
    add(prong, new THREE.BoxGeometry(0.02, 0.032, 0.34), M.bone, `prong_blade_${side(s)}`, [0, 0, -0.17]);
    add(prong, new THREE.BoxGeometry(0.005, 0.01, 0.3), M.glow, `prong_nerve_${side(s)}`, [-s * 0.011, 0, -0.17]);
    add(prong, new THREE.SphereGeometry(0.019, 14, 10), M.glow, `arc_tip_${side(s)}`, [0, 0, -0.35]);
    add(prong, new THREE.ConeGeometry(0.012, 0.06, 5), M.bone, `prong_barb_${side(s)}`, [0, 0.03, -0.3], [-0.6, 0, 0]);
  });
  grip(THREE, c, root, -0.1, 0.13);
  grp(root, 'anchor_muzzle', [0, 0.01, -0.46]);
}

function ripper(THREE, c, root) {
  const { M, add, grp } = c;
  // "Ripper" — a bone saw spun up in a forked cradle and thrown.
  const body = grp(root, 'spinner_body', [0, 0, 0.08]);
  add(body, new THREE.SphereGeometry(0.075, 22, 16), M.chitin, 'body_shell', [0, 0, 0], [0, 0, 0], [1, 0.8, 1.7]);
  add(body, new THREE.SphereGeometry(0.05, 18, 14), M.membrane, 'tendon_sac', [0, -0.05, 0.02], [0, 0, 0], [1, 0.8, 1.4]);
  add(body, new THREE.SphereGeometry(0.024, 14, 10), M.glow, 'spin_node', [0, 0.05, 0]);
  [-1, 1].forEach((s) => {
    add(root, new THREE.BoxGeometry(0.02, 0.03, 0.34), M.bone, `cradle_arm_${side(s)}`, [s * 0.125, 0, -0.17], [0, s * -0.1, 0]);
    add(root, new THREE.SphereGeometry(0.018, 12, 10), M.graft, `cradle_pin_${side(s)}`, [s * 0.13, 0, -0.3]);
  });
  const disc = grp(root, 'saw_disc', [0, 0, -0.27]);
  add(disc, new THREE.CylinderGeometry(0.105, 0.105, 0.012, 28), M.bone, 'disc_plate', [0, 0, 0]);
  add(disc, new THREE.CylinderGeometry(0.03, 0.03, 0.03, 16), M.graft, 'disc_hub_cap', [0, 0, 0]);
  add(disc, new THREE.TorusGeometry(0.07, 0.006, 6, 24), M.glow, 'disc_ring', [0, 0.008, 0], [HALF_PI, 0, 0]);
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2;
    add(disc, new THREE.ConeGeometry(0.014, 0.05, 4), M.bone, `disc_tooth_${i + 1}`,
      [Math.cos(a) * 0.122, 0, Math.sin(a) * 0.122], [0, -a, -HALF_PI]);
  }
  grip(THREE, c, root, -0.1, 0.14);
  grp(root, 'anchor_muzzle', [0, 0, -0.42]);
}

/* ============================ enemies ============================ */

function spitter(THREE, c, root) {
  const { M, add, grp, spur, limb } = c;
  // "Bile Spitter" — a walking stomach. Lobs acid in an arc; the throat sac swells before each shot.
  const body = grp(root, 'body', [0, 0.62, 0.06]);
  add(body, new THREE.SphereGeometry(0.4, 26, 20), M.chitin, 'body_shell', [0, 0, 0], [0, 0, 0], [1.15, 0.8, 1.4]);
  for (let i = 0; i < 4; i++) spur(body, `dorsal_spur_${i + 1}`, M.bone, [0, 0.3, -0.25 + i * 0.2], [-0.4, 0, 0], 0.045, 0.24);
  band(THREE, c, body, 'belly_band', M.bone, 0.42, 0.03, [0, 0, 0.1], 'z');

  const throat = grp(root, 'throat', [0, 0.6, -0.42]);
  add(throat, new THREE.SphereGeometry(0.3, 24, 18), M.membrane, 'throat_sac', [0, 0, 0]);
  add(throat, new THREE.SphereGeometry(0.15, 20, 16), M.glow, 'bile_core', [0, 0, 0]);

  const snout = grp(root, 'mortar_snout', [0, 0.88, -0.34], [-0.75, 0, 0]);
  add(snout, new THREE.CylinderGeometry(0.1, 0.15, 0.46, 18, 1, true), M.chitin, 'snout_tube', [0, 0.2, 0]);
  band(THREE, c, snout, 'snout_lip', M.bone, 0.1, 0.022, [0, 0.43, 0], 'y');
  add(snout, new THREE.SphereGeometry(0.06, 14, 10), M.glow, 'snout_gland', [0, 0.36, 0]);
  [-1, 1].forEach((s) => add(root, new THREE.SphereGeometry(0.05, 14, 10), M.glow, `eye_${side(s)}`, [s * 0.22, 0.86, -0.2]));

  limb(root, 'foreleg_l', M.chitin, { at: [-0.34, 0.56, -0.2], upper: 0.22, lower: 0.24, r: 0.08, a1: 0.4, a2: -0.8, claw: 0.1, spread: 0.3 });
  limb(root, 'foreleg_r', M.chitin, { at: [0.34, 0.56, -0.2], upper: 0.22, lower: 0.24, r: 0.08, a1: 0.4, a2: -0.8, claw: 0.1, spread: -0.3 });
  limb(root, 'hindleg_l', M.chitin, { at: [-0.36, 0.56, 0.36], upper: 0.24, lower: 0.24, r: 0.09, a1: -0.4, a2: 0.8, claw: 0.1, spread: 0.3 });
  limb(root, 'hindleg_r', M.chitin, { at: [0.36, 0.56, 0.36], upper: 0.24, lower: 0.24, r: 0.09, a1: -0.4, a2: 0.8, claw: 0.1, spread: -0.3 });
  grp(root, 'anchor_muzzle', [0, 1.2, -0.62]);
}

function shielder(THREE, c, root) {
  const { M, add, grp, spur, limb } = c;
  // "Carapace Bulwark" — 1.9 m. Nothing gets through the plate; go around it.
  const torso = grp(root, 'torso', [0, 1.18, 0.05]);
  add(torso, new THREE.CapsuleGeometry(0.27, 0.56, 6, 20), M.chitin, 'torso_shell', [0, 0, 0]);
  add(torso, new THREE.SphereGeometry(0.2, 20, 16), M.membrane, 'back_sac', [0, 0.05, 0.2], [0, 0, 0], [1, 1.2, 0.7]);
  add(torso, new THREE.SphereGeometry(0.1, 16, 12), M.glow, 'back_core', [0, 0.05, 0.3]);
  for (let i = 0; i < 3; i++) band(THREE, c, torso, `torso_band_${i + 1}`, M.bone, 0.28, 0.025, [0, -0.2 + i * 0.2, 0], 'y');

  const head = grp(root, 'head', [0, 1.78, -0.04]);
  add(head, new THREE.SphereGeometry(0.16, 20, 16), M.chitin, 'head_shell', [0, 0, 0], [0, 0, 0], [1, 0.9, 1.1]);
  add(head, new THREE.BoxGeometry(0.2, 0.035, 0.03), M.glow, 'eye_slit', [0, 0.01, -0.16]);
  spur(head, 'crest_spur', M.bone, [0, 0.16, 0.02], [-0.5, 0, 0], 0.04, 0.24);

  const shield = grp(root, 'shield', [0, 1.02, -0.5]);
  add(shield, new THREE.BoxGeometry(1.05, 1.5, 0.1), M.bone, 'shield_plate', [0, 0, 0]);
  add(shield, new THREE.BoxGeometry(0.9, 1.3, 0.06), M.chitin, 'shield_backing', [0, 0, 0.07]);
  add(shield, new THREE.BoxGeometry(0.05, 1.3, 0.03), M.glow, 'shield_seam', [0, 0, -0.06]);
  [-1, 1].forEach((s) => {
    add(shield, new THREE.BoxGeometry(0.14, 1.36, 0.14), M.chitin, `shield_rim_${side(s)}`, [s * 0.52, 0, 0.02], [0, s * -0.3, 0]);
    for (let i = 0; i < 3; i++) spur(shield, `shield_spike_${side(s)}_${i + 1}`, M.bone, [s * 0.3, 0.45 - i * 0.45, -0.07], [-HALF_PI, 0, 0], 0.045, 0.16);
    const arm = grp(root, `arm_${side(s)}`, [s * 0.34, 1.42, -0.04], [-1.2, 0, s * 0.15]);
    add(arm, new THREE.CapsuleGeometry(0.085, 0.4, 4, 14), M.chitin, `arm_shell_${side(s)}`, [0, -0.2, 0]);
  });

  limb(root, 'leg_l', M.chitin, { at: [-0.18, 0.86, 0.06], upper: 0.38, lower: 0.38, r: 0.1, a1: 0.2, a2: -0.42, claw: 0.14, spread: 0.1 });
  limb(root, 'leg_r', M.chitin, { at: [0.18, 0.86, 0.06], upper: 0.38, lower: 0.38, r: 0.1, a1: 0.2, a2: -0.42, claw: 0.14, spread: -0.1 });
}

function leaper(THREE, c, root) {
  const { M, add, grp, spur, limb } = c;
  // "Tendon Leaper" — all hind leg. Coils, then crosses the room in one jump.
  const body = grp(root, 'body', [0, 0.52, 0], [0.18, 0, 0]);
  add(body, new THREE.CapsuleGeometry(0.2, 0.46, 6, 20), M.chitin, 'body_shell', [0, 0, 0], [HALF_PI, 0, 0]);
  add(body, new THREE.SphereGeometry(0.16, 20, 16), M.membrane, 'tendon_sac', [0, -0.08, 0.2], [0, 0, 0], [1, 0.8, 1.3]);
  [-1, 1].forEach((s) => add(body, new THREE.BoxGeometry(0.02, 0.05, 0.44), M.glow, `flank_seam_${side(s)}`, [s * 0.19, 0, 0]));
  for (let i = 0; i < 4; i++) add(body, new THREE.BoxGeometry(0.012, 0.16 - i * 0.02, 0.1), M.membrane, `sail_fin_${i + 1}`, [0, 0.24, -0.2 + i * 0.14]);

  const head = grp(root, 'head', [0, 0.5, -0.44]);
  add(head, new THREE.SphereGeometry(0.15, 22, 16), M.chitin, 'skull', [0, 0, 0], [0, 0, 0], [1.1, 0.8, 1.3]);
  add(head, new THREE.BoxGeometry(0.2, 0.04, 0.2), M.bone, 'jaw', [0, -0.09, -0.08], [-0.2, 0, 0]);
  [-1, 1].forEach((s) => {
    add(head, new THREE.SphereGeometry(0.04, 12, 10), M.glow, `eye_${side(s)}`, [s * 0.09, 0.04, -0.13]);
    spur(head, `tusk_${side(s)}`, M.bone, [s * 0.08, -0.08, -0.2], [-HALF_PI * 1.2, 0, 0], 0.02, 0.12);
  });

  limb(root, 'foreleg_l', M.chitin, { at: [-0.18, 0.48, -0.24], upper: 0.24, lower: 0.24, r: 0.055, a1: 0.5, a2: -0.9, claw: 0.09, spread: 0.2 });
  limb(root, 'foreleg_r', M.chitin, { at: [0.18, 0.48, -0.24], upper: 0.24, lower: 0.24, r: 0.055, a1: 0.5, a2: -0.9, claw: 0.09, spread: -0.2 });
  limb(root, 'hindleg_l', M.chitin, { at: [-0.22, 0.6, 0.3], upper: 0.5, lower: 0.56, r: 0.085, a1: -1.25, a2: 2.2, claw: 0.14, spread: 0.2 });
  limb(root, 'hindleg_r', M.chitin, { at: [0.22, 0.6, 0.3], upper: 0.5, lower: 0.56, r: 0.085, a1: -1.25, a2: 2.2, claw: 0.14, spread: -0.2 });
}

function swarmling(THREE, c, root) {
  const { M, add, grp, spur } = c;
  // "Broodling" — knee high, fast, never alone.
  const body = grp(root, 'body', [0, 0.2, 0.02]);
  add(body, new THREE.SphereGeometry(0.16, 18, 14), M.chitin, 'shell', [0, 0, 0], [0, 0, 0], [1, 0.7, 1.45]);
  add(body, new THREE.SphereGeometry(0.09, 14, 12), M.glow, 'brood_spot', [0, 0.05, 0.12], [0, 0, 0], [1, 0.6, 1]);
  for (let i = 0; i < 3; i++) spur(body, `back_spur_${i + 1}`, M.bone, [0, 0.11, -0.1 + i * 0.09], [-0.5, 0, 0], 0.02, 0.1);
  const head = grp(root, 'head', [0, 0.2, -0.24]);
  add(head, new THREE.SphereGeometry(0.08, 14, 12), M.chitin, 'skull', [0, 0, 0]);
  [-1, 1].forEach((s) => {
    spur(head, `mandible_${side(s)}`, M.bone, [s * 0.045, -0.02, -0.08], [-HALF_PI, s * 0.3, 0], 0.016, 0.1);
    add(head, new THREE.SphereGeometry(0.02, 8, 8), M.glow, `eye_${side(s)}`, [s * 0.045, 0.03, -0.06]);
    for (let i = 0; i < 3; i++) {
      const leg = grp(root, `leg_${side(s)}_${i + 1}`, [s * 0.13, 0.17, -0.1 + i * 0.11], [0, 0, s * -0.9]);
      add(leg, new THREE.CapsuleGeometry(0.018, 0.14, 3, 8), M.chitin, `leg_seg_${side(s)}_${i + 1}`, [0, -0.07, 0]);
    }
  });
}

function drone(THREE, c, root) {
  const { M, add, grp, spur } = c;
  // "Sting Drone" — hovers out of reach and fires down. Wings blur; the stinger is the gun.
  const thorax = grp(root, 'thorax', [0, 0.62, 0]);
  add(thorax, new THREE.SphereGeometry(0.2, 22, 16), M.chitin, 'thorax_shell', [0, 0, 0], [0, 0, 0], [1, 0.9, 1.3]);
  band(THREE, c, thorax, 'thorax_band', M.bone, 0.2, 0.02, [0, 0, 0]);
  const head = grp(root, 'head', [0, 0.66, -0.3]);
  add(head, new THREE.SphereGeometry(0.12, 18, 14), M.chitin, 'head_shell', [0, 0, 0]);
  [-1, 1].forEach((s) => add(head, new THREE.SphereGeometry(0.065, 14, 12), M.glow, `compound_eye_${side(s)}`, [s * 0.075, 0.02, -0.07]));

  const abdomen = grp(root, 'abdomen', [0, 0.52, 0.22], [0.9, 0, 0]);
  add(abdomen, new THREE.CapsuleGeometry(0.14, 0.3, 5, 16), M.membrane, 'venom_abdomen', [0, -0.2, 0]);
  add(abdomen, new THREE.SphereGeometry(0.08, 14, 12), M.glow, 'sting_core', [0, -0.22, 0]);
  for (let i = 0; i < 3; i++) band(THREE, c, abdomen, `abdomen_band_${i + 1}`, M.bone, 0.145 - i * 0.012, 0.014, [0, -0.08 - i * 0.12, 0], 'y');
  spur(abdomen, 'stinger', M.bone, [0, -0.5, 0], [Math.PI, 0, 0], 0.045, 0.26);

  [-1, 1].forEach((s) => {
    const wing = grp(root, `wing_${side(s)}`, [s * 0.16, 0.76, 0.02], [0, 0, s * 0.35]);
    add(wing, new THREE.BoxGeometry(0.62, 0.008, 0.2), M.membrane, `wing_fore_${side(s)}`, [s * 0.33, 0, -0.06], [0, s * 0.2, 0]);
    add(wing, new THREE.BoxGeometry(0.46, 0.008, 0.15), M.membrane, `wing_hind_${side(s)}`, [s * 0.26, -0.01, 0.14], [0, s * -0.25, 0]);
    add(wing, new THREE.BoxGeometry(0.6, 0.012, 0.014), M.bone, `wing_strut_${side(s)}`, [s * 0.32, 0.004, -0.14], [0, s * 0.2, 0]);
  });
  grp(root, 'anchor_muzzle', [0, 0.1, 0.42]);
}

function broodmother(THREE, c, root) {
  const { M, add, grp, spur } = c;
  // "Brood Mother" — slow, swollen, and never stops laying. Kill it first.
  const abdomen = grp(root, 'abdomen', [0, 1.05, 0.5]);
  add(abdomen, new THREE.SphereGeometry(0.95, 28, 20), M.membrane, 'egg_abdomen', [0, 0, 0], [0, 0, 0], [1, 0.9, 1.25]);
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 2;
    add(abdomen, new THREE.SphereGeometry(0.2, 14, 12), M.glow, `egg_${i + 1}`, [Math.cos(a) * 0.6, -0.1 + Math.sin(a * 2) * 0.3, Math.sin(a) * 0.75]);
  }
  for (let i = 0; i < 4; i++) add(abdomen, new THREE.BoxGeometry(0.9 - i * 0.12, 0.08, 0.3), M.chitin, `dorsal_plate_${i + 1}`, [0, 0.82 - i * 0.04, -0.6 + i * 0.4], [0.25 - i * 0.2, 0, 0]);

  const thorax = grp(root, 'thorax', [0, 1.3, -0.6]);
  add(thorax, new THREE.SphereGeometry(0.5, 24, 18), M.chitin, 'thorax_shell', [0, 0, 0], [0, 0, 0], [1.1, 1, 1]);
  add(thorax, new THREE.SphereGeometry(0.2, 18, 14), M.glow, 'brood_core', [0, -0.05, -0.42]);
  const head = grp(root, 'head', [0, 1.75, -0.95]);
  add(head, new THREE.SphereGeometry(0.24, 20, 16), M.chitin, 'skull', [0, 0, 0], [0, 0, 0], [1.2, 0.9, 1]);
  [-1, 1].forEach((s) => {
    for (let i = 0; i < 2; i++) add(head, new THREE.SphereGeometry(0.05, 10, 8), M.glow, `eye_${side(s)}_${i + 1}`, [s * (0.1 + i * 0.09), 0.04 - i * 0.05, -0.2]);
    spur(head, `mandible_${side(s)}`, M.bone, [s * 0.12, -0.16, -0.2], [-HALF_PI * 1.3, 0, s * 0.3], 0.05, 0.3);
    for (let i = 0; i < 3; i++) {
      splayLeg(THREE, c, root, `leg_${side(s)}_${i + 1}`, M.chitin, {
        at: [s * 0.5, 1.2, -0.7 + i * 0.5], upper: 0.75, lower: 1.1, r: 0.085, out: s * -1.0, bend: s * -1.75, yaw: s * (0.4 - i * 0.4),
      });
    }
  });
}

/* ============================ bosses ============================ */

function matriarch(THREE, c, root) {
  const { M, add, grp, spur } = c;
  // "Hive Matriarch" — 4.6 m at the crown. The abdomen is the nest; the eggs on it are real.
  const abdomen = grp(root, 'abdomen', [0, 2.3, 2.2]);
  add(abdomen, new THREE.SphereGeometry(1.75, 32, 24), M.membrane, 'nest_abdomen', [0, 0, 0], [0, 0, 0], [1, 0.9, 1.35]);
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2;
    add(abdomen, new THREE.SphereGeometry(0.32, 16, 12), M.glow, `egg_glow_${i + 1}`,
      [Math.cos(a) * 1.25, 0.2 + Math.sin(a * 3) * 0.55, Math.sin(a) * 1.7]);
  }
  for (let i = 0; i < 6; i++) {
    add(abdomen, new THREE.BoxGeometry(1.9 - i * 0.2, 0.14, 0.62), M.chitin, `dorsal_plate_${i + 1}`,
      [0, 1.5 - i * 0.07 - Math.abs(i - 2) * 0.06, -1.5 + i * 0.6], [0.35 - i * 0.14, 0, 0]);
    spur(abdomen, `dorsal_spine_${i + 1}`, M.bone, [0, 1.75 - Math.abs(i - 2) * 0.1, -1.5 + i * 0.6], [-0.3, 0, 0], 0.09, 0.6);
  }
  spur(abdomen, 'ovipositor', M.bone, [0, -0.4, 2.5], [HALF_PI * 1.2, 0, 0], 0.22, 1.1);

  const thorax = grp(root, 'thorax', [0, 2.9, -0.35], [0.3, 0, 0]);
  add(thorax, new THREE.SphereGeometry(0.95, 28, 22), M.chitin, 'thorax_shell', [0, 0, 0], [0, 0, 0], [1.05, 1.25, 0.9]);
  for (let i = 0; i < 4; i++) band(THREE, c, thorax, `thorax_band_${i + 1}`, M.bone, 0.92 - Math.abs(i - 1.5) * 0.12, 0.07, [0, -0.6 + i * 0.4, 0], 'y');
  add(thorax, new THREE.SphereGeometry(0.62, 24, 18), M.membrane, 'chest_cavity', [0, -0.1, -0.5], [0, 0, 0], [1, 1.1, 0.7]);
  add(thorax, new THREE.SphereGeometry(0.42, 24, 18), M.glow, 'phase_core', [0, -0.1, -0.62]);

  const head = grp(root, 'head', [0, 4.25, -0.95], [0.25, 0, 0]);
  add(head, new THREE.SphereGeometry(0.52, 24, 18), M.chitin, 'skull_shell', [0, 0, 0], [0, 0, 0], [1.1, 0.95, 1.1]);
  for (let i = 0; i < 9; i++) {
    const a = -1.0 + i * 0.25;
    spur(head, `crown_spur_${i + 1}`, M.bone, [Math.sin(a) * 0.48, 0.38, 0.05 - Math.cos(a) * 0.12], [-0.3, 0, Math.sin(a) * -1.1], 0.07, 0.75 - Math.abs(a) * 0.3);
  }
  [-1, 1].forEach((s) => {
    for (let i = 0; i < 3; i++) add(head, new THREE.SphereGeometry(0.085 - i * 0.015, 12, 10), M.glow, `eye_${side(s)}_${i + 1}`, [s * (0.16 + i * 0.12), 0.08 - i * 0.1, -0.44 + i * 0.05]);
    spur(head, `mandible_${side(s)}`, M.bone, [s * 0.26, -0.42, -0.4], [-HALF_PI * 1.35, 0, s * 0.35], 0.11, 0.8);

    const scythe = grp(root, `scythe_${side(s)}`, [s * 0.95, 3.2, -0.7], [-0.5, 0, s * 0.35]);
    add(scythe, new THREE.CapsuleGeometry(0.2, 1.0, 5, 16), M.chitin, `scythe_upper_${side(s)}`, [0, -0.55, 0]);
    add(scythe, new THREE.SphereGeometry(0.26, 16, 12), M.chitin, `scythe_elbow_${side(s)}`, [0, -1.15, 0]);
    const blade = grp(scythe, `scythe_blade_grp_${side(s)}`, [0, -1.15, 0], [-1.5, 0, 0]);
    add(blade, new THREE.BoxGeometry(0.1, 1.7, 0.34), M.bone, `scythe_blade_${side(s)}`, [0, -0.85, 0]);
    add(blade, new THREE.BoxGeometry(0.03, 1.6, 0.05), M.glow, `scythe_edge_${side(s)}`, [0, -0.85, -0.17]);
    add(blade, new THREE.ConeGeometry(0.17, 0.6, 4), M.bone, `scythe_tip_${side(s)}`, [0, -1.95, 0], [Math.PI, 0, 0]);

    for (let i = 0; i < 3; i++) {
      splayLeg(THREE, c, root, `leg_${side(s)}_${i + 1}`, M.chitin, {
        at: [s * 0.9, 2.5, -0.2 + i * 0.95], upper: 1.7, lower: 2.6, r: 0.17, out: s * -0.95, bend: s * -1.8, yaw: s * (0.45 - i * 0.45),
      });
    }
  });
  grp(root, 'anchor_muzzle', [0, 4.0, -1.5]);
}

function stalker(THREE, c, root) {
  const { M, add, grp, spur, limb } = c;
  // "Rift Stalker" — 3.4 m, almost no width. It is never where the last hit landed.
  const torso = grp(root, 'torso', [0, 2.25, 0.05], [0.28, 0, 0]);
  add(torso, new THREE.CapsuleGeometry(0.3, 0.95, 6, 20), M.chitin, 'torso_shell', [0, 0, 0]);
  for (let i = 0; i < 5; i++) band(THREE, c, torso, `rib_band_${i + 1}`, M.bone, 0.31 - Math.abs(i - 2) * 0.02, 0.03, [0, -0.4 + i * 0.2, 0], 'y');
  add(torso, new THREE.SphereGeometry(0.24, 20, 16), M.membrane, 'chest_window', [0, 0.1, -0.2], [0, 0, 0], [1, 1.3, 0.6]);
  add(torso, new THREE.SphereGeometry(0.17, 20, 16), M.glow, 'phase_core', [0, 0.1, -0.27]);
  for (let i = 0; i < 5; i++) spur(torso, `spine_${i + 1}`, M.bone, [0, 0.45 - i * 0.22, 0.3], [HALF_PI * 0.7, 0, 0], 0.045, 0.5 - i * 0.05);

  const head = grp(root, 'head', [0, 3.2, -0.34], [0.35, 0, 0]);
  add(head, new THREE.SphereGeometry(0.2, 22, 16), M.chitin, 'skull', [0, 0, 0], [0, 0, 0], [0.85, 0.9, 1.7]);
  add(head, new THREE.BoxGeometry(0.26, 0.04, 0.05), M.glow, 'eye_slit', [0, 0.03, -0.3]);
  spur(head, 'crest', M.bone, [0, 0.17, 0.15], [0.9, 0, 0], 0.06, 0.6);
  const halo = grp(root, 'rift_halo', [0, 3.15, 0.22], [0.3, 0, 0]);
  add(halo, new THREE.TorusGeometry(0.62, 0.035, 8, 30, Math.PI * 1.5), M.glow, 'halo_arc', [0, 0, 0], [0, 0, Math.PI * 0.75]);
  add(halo, new THREE.TorusGeometry(0.78, 0.02, 6, 30, Math.PI * 1.1), M.graft, 'halo_outer', [0, 0, 0.03], [0, 0, Math.PI * 0.95]);

  [-1, 1].forEach((s) => {
    add(torso, new THREE.SphereGeometry(0.2, 16, 12), M.chitin, `shoulder_${side(s)}`, [s * 0.38, 0.42, 0]);
    const arm = grp(root, `arm_${side(s)}`, [s * 0.44, 2.68, -0.08], [0.5, 0, s * 0.22]);
    add(arm, new THREE.CapsuleGeometry(0.09, 0.8, 4, 14), M.chitin, `upper_arm_${side(s)}`, [0, -0.45, 0]);
    add(arm, new THREE.SphereGeometry(0.12, 14, 12), M.chitin, `elbow_${side(s)}`, [0, -0.92, 0]);
    const blade = grp(arm, `blade_grp_${side(s)}`, [0, -0.92, 0], [-1.25, 0, 0]);
    add(blade, new THREE.BoxGeometry(0.05, 1.5, 0.2), M.bone, `blade_${side(s)}`, [0, -0.75, 0]);
    add(blade, new THREE.BoxGeometry(0.018, 1.45, 0.03), M.glow, `blade_edge_${side(s)}`, [0, -0.75, -0.1]);
    add(blade, new THREE.ConeGeometry(0.1, 0.5, 4), M.bone, `blade_tip_${side(s)}`, [0, -1.72, 0], [Math.PI, 0, 0]);
  });
  limb(root, 'leg_l', M.chitin, { at: [-0.2, 1.72, 0.12], upper: 0.85, lower: 0.9, r: 0.1, a1: 0.55, a2: -1.1, claw: 0.22, spread: 0.1 });
  limb(root, 'leg_r', M.chitin, { at: [0.2, 1.72, 0.12], upper: 0.85, lower: 0.9, r: 0.1, a1: 0.35, a2: -0.8, claw: 0.22, spread: -0.1 });
  const tail = grp(root, 'tail', [0, 1.8, 0.35], [1.0, 0, 0]);
  add(tail, new THREE.CapsuleGeometry(0.08, 0.9, 4, 12), M.chitin, 'tail_base', [0, 0.5, 0]);
  add(tail, new THREE.ConeGeometry(0.07, 0.6, 6), M.bone, 'tail_barb', [0, 1.25, 0]);
  grp(root, 'anchor_muzzle', [0, 2.35, -0.6]);
}

function core(THREE, c, root) {
  const { M, add, grp, spur } = c;
  // "Fracture Core" — the thing the hive grew around. It does not move. The rings do.
  const heart = grp(root, 'heart', [0, 3.4, 0]);
  add(heart, new THREE.SphereGeometry(0.95, 32, 24), M.glow, 'phase_core', [0, 0, 0]);
  add(heart, new THREE.SphereGeometry(1.25, 28, 20), M.membrane, 'heart_shell', [0, 0, 0]);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    add(heart, new THREE.BoxGeometry(0.16, 2.3, 0.3), M.chitin, `cage_rib_${i + 1}`, [Math.cos(a) * 1.3, 0, Math.sin(a) * 1.3], [0, -a, 0]);
  }
  band(THREE, c, heart, 'cage_crown', M.bone, 1.32, 0.1, [0, 1.15, 0], 'y');
  band(THREE, c, heart, 'cage_base', M.bone, 1.32, 0.1, [0, -1.15, 0], 'y');

  const ringA = grp(root, 'ring_a', [0, 3.4, 0]);
  add(ringA, new THREE.TorusGeometry(2.1, 0.15, 10, 40), M.bone, 'ring_a_band', [0, 0, 0], [HALF_PI, 0, 0]);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    spur(ringA, `ring_a_spike_${i + 1}`, M.bone, [Math.cos(a) * 2.35, 0, Math.sin(a) * 2.35], [0, -a, -HALF_PI], 0.13, 0.7);
  }
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2 + Math.PI / 4;
    add(ringA, new THREE.SphereGeometry(0.3, 16, 12), M.glow, `shield_node_${i + 1}`, [Math.cos(a) * 2.1, 0, Math.sin(a) * 2.1]);
  }
  const ringB = grp(root, 'ring_b', [0, 3.4, 0], [0.6, 0, 0.4]);
  add(ringB, new THREE.TorusGeometry(2.6, 0.1, 8, 44), M.chitin, 'ring_b_band', [0, 0, 0], [HALF_PI, 0, 0]);
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    add(ringB, new THREE.BoxGeometry(0.5, 0.06, 0.2), M.glow, `ring_b_seam_${i + 1}`, [Math.cos(a) * 2.6, 0, Math.sin(a) * 2.6], [0, -a + HALF_PI, 0]);
  }
  const ringC = grp(root, 'ring_c', [0, 3.4, 0], [-0.5, 0, -0.7]);
  add(ringC, new THREE.TorusGeometry(3.0, 0.07, 8, 48), M.graft, 'ring_c_band', [0, 0, 0], [HALF_PI, 0, 0]);

  const roots = grp(root, 'roots', [0, 0, 0]);
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 2;
    const r = 1.2 + (i % 2) * 0.5;
    add(roots, new THREE.CylinderGeometry(0.1, 0.24, 2.4, 10), M.chitin, `tendril_${i + 1}`,
      [Math.cos(a) * r * 0.55, 1.2, Math.sin(a) * r * 0.55], [Math.sin(a) * 0.42, 0, -Math.cos(a) * 0.42]);
    spur(roots, `root_claw_${i + 1}`, M.bone, [Math.cos(a) * r, 0.25, Math.sin(a) * r], [0, 0, 0], 0.16, 0.5);
  }
  band(THREE, c, roots, 'root_ring', M.bone, 1.9, 0.12, [0, 0.12, 0], 'y');
  add(roots, new THREE.TorusGeometry(1.5, 0.04, 6, 36), M.glow, 'root_glow', [0, 0.2, 0], [HALF_PI, 0, 0]);
  grp(root, 'anchor_muzzle', [0, 3.4, 0]);
}

/* ============================ player ============================ */

function host(THREE, c, root) {
  const { M, add, grp, spur, limb } = c;
  // "Grafted Host" — the player, seen from outside. The right arm is the symbiont.
  const torso = grp(root, 'torso', [0, 1.18, 0]);
  add(torso, new THREE.CapsuleGeometry(0.2, 0.42, 5, 18), M.graft, 'torso_plate', [0, 0, 0]);
  add(torso, new THREE.SphereGeometry(0.16, 18, 14), M.chitin, 'chest_graft', [0.06, 0.08, -0.12], [0, 0, 0], [1.1, 1, 0.7]);
  add(torso, new THREE.SphereGeometry(0.07, 14, 12), M.glow, 'chest_node', [0.06, 0.08, -0.2]);
  add(torso, new THREE.BoxGeometry(0.26, 0.3, 0.14), M.graft, 'back_pack', [0, 0.06, 0.2]);
  [-1, 1].forEach((s) => add(torso, new THREE.BoxGeometry(0.03, 0.26, 0.03), M.glow, `pack_vent_${side(s)}`, [s * 0.09, 0.06, 0.275]));
  add(root, new THREE.CapsuleGeometry(0.17, 0.12, 4, 14), M.graft, 'pelvis', [0, 0.84, 0], [0, 0, HALF_PI]);

  const head = grp(root, 'head', [0, 1.68, -0.02]);
  add(head, new THREE.SphereGeometry(0.14, 20, 16), M.graft, 'helmet', [0, 0, 0], [0, 0, 0], [1, 1.05, 1.1]);
  add(head, new THREE.BoxGeometry(0.2, 0.06, 0.06), M.glow, 'visor', [0, 0.01, -0.13]);
  spur(head, 'helmet_fin', M.bone, [0, 0.13, 0.04], [0.8, 0, 0], 0.03, 0.2);

  const armL = grp(root, 'arm_l', [-0.3, 1.42, 0], [-0.9, 0, -0.1]);
  add(armL, new THREE.CapsuleGeometry(0.065, 0.5, 4, 12), M.graft, 'arm_plate_l', [0, -0.28, 0]);
  const armR = grp(root, 'arm_r', [0.3, 1.42, 0], [-1.35, 0, 0.08]);
  add(armR, new THREE.CapsuleGeometry(0.095, 0.5, 4, 14), M.chitin, 'symbiont_arm', [0, -0.28, 0]);
  add(armR, new THREE.SphereGeometry(0.13, 16, 12), M.membrane, 'symbiont_sac', [0, -0.3, 0.06]);
  add(armR, new THREE.CylinderGeometry(0.04, 0.06, 0.4, 12), M.bone, 'symbiont_barrel', [0, -0.72, 0]);
  add(armR, new THREE.SphereGeometry(0.035, 12, 10), M.glow, 'symbiont_muzzle', [0, -0.93, 0]);
  [-1, 1].forEach((s) => add(torso, new THREE.SphereGeometry(0.11, 14, 12), s > 0 ? M.chitin : M.graft, `shoulder_${side(s)}`, [s * 0.29, 0.22, 0]));

  limb(root, 'leg_l', M.graft, { at: [-0.12, 0.82, 0], upper: 0.36, lower: 0.38, r: 0.075, a1: 0.12, a2: -0.24, claw: 0.1, spread: 0.06 });
  limb(root, 'leg_r', M.graft, { at: [0.12, 0.82, 0], upper: 0.36, lower: 0.38, r: 0.075, a1: -0.1, a2: -0.1, claw: 0.1, spread: -0.06 });
}

/* ============================ props ============================ */

function props(THREE, c, root) {
  const { M, add, grp, spur } = c;
  // one diorama of arena pieces; the game pulls each named group out on its own.

  // jump pad — a tympanum stretched over a muscle ring
  const pad = grp(root, 'jump_pad', [0, 0, 0]);
  add(pad, new THREE.CylinderGeometry(1.05, 1.2, 0.16, 28), M.chitin, 'pad_base', [0, 0.08, 0]);
  add(pad, new THREE.CylinderGeometry(0.86, 0.86, 0.06, 28), M.membrane, 'pad_drum', [0, 0.18, 0]);
  add(pad, new THREE.TorusGeometry(0.92, 0.05, 8, 32), M.glow, 'pad_ring', [0, 0.19, 0], [HALF_PI, 0, 0]);
  add(pad, new THREE.TorusGeometry(0.45, 0.03, 8, 24), M.glow, 'pad_inner_ring', [0, 0.215, 0], [HALF_PI, 0, 0]);
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    spur(pad, `pad_spur_${i + 1}`, M.bone, [Math.cos(a) * 1.08, 0.2, Math.sin(a) * 1.08], [Math.sin(a) * -0.5, 0, Math.cos(a) * 0.5], 0.06, 0.3);
  }

  // spawn pod — what enemies climb out of
  const pod = grp(root, 'spawn_pod', [4, 0, 0]);
  add(pod, new THREE.SphereGeometry(0.5, 22, 16), M.membrane, 'pod_shell', [0, 0.62, 0], [0, 0, 0], [1, 1.3, 1]);
  add(pod, new THREE.SphereGeometry(0.26, 18, 14), M.glow, 'pod_core', [0, 0.6, 0]);
  add(pod, new THREE.CylinderGeometry(0.42, 0.6, 0.3, 18), M.chitin, 'pod_collar', [0, 0.15, 0]);
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2;
    spur(pod, `pod_petal_${i + 1}`, M.bone, [Math.cos(a) * 0.45, 0.5, Math.sin(a) * 0.45], [Math.sin(a) * 0.35, 0, -Math.cos(a) * 0.35], 0.09, 0.7);
  }

  // shop altar — a tithe bowl
  const altar = grp(root, 'shop_altar', [8, 0, 0]);
  add(altar, new THREE.BoxGeometry(1.7, 0.55, 0.95), M.bone, 'altar_slab', [0, 0.275, 0]);
  add(altar, new THREE.BoxGeometry(1.9, 0.12, 1.1), M.chitin, 'altar_lip', [0, 0.6, 0]);
  add(altar, new THREE.SphereGeometry(0.38, 22, 14, 0, Math.PI * 2, HALF_PI, HALF_PI), M.chitin, 'altar_bowl', [0, 1.02, 0]);
  add(altar, new THREE.SphereGeometry(0.26, 18, 14), M.glow, 'altar_glow', [0, 0.92, 0], [0, 0, 0], [1, 0.5, 1]);
  [-1, 1].forEach((s) => {
    spur(altar, `altar_horn_${side(s)}`, M.bone, [s * 0.8, 1.15, 0], [0, 0, s * -0.25], 0.11, 1.2);
    add(altar, new THREE.BoxGeometry(0.05, 0.4, 0.8), M.glow, `altar_seam_${side(s)}`, [s * 0.86, 0.3, 0]);
  });

  // door arch — the way on
  const arch = grp(root, 'door_arch', [-5, 0, 0]);
  [-1, 1].forEach((s) => {
    add(arch, new THREE.CylinderGeometry(0.16, 0.3, 3.4, 12), M.bone, `arch_post_${side(s)}`, [s * 1.45, 1.7, 0]);
    add(arch, new THREE.BoxGeometry(0.05, 2.9, 0.05), M.glow, `arch_vein_${side(s)}`, [s * 1.26, 1.6, 0]);
    spur(arch, `arch_horn_${side(s)}`, M.bone, [s * 1.6, 3.7, 0], [0, 0, s * -0.5], 0.14, 0.9);
  });
  add(arch, new THREE.TorusGeometry(1.45, 0.17, 10, 26, Math.PI), M.bone, 'arch_span', [0, 3.3, 0]);
  add(arch, new THREE.BoxGeometry(2.5, 3.2, 0.04), M.membrane, 'arch_veil', [0, 1.65, 0]);
  add(arch, new THREE.SphereGeometry(0.2, 14, 12), M.glow, 'arch_keystone', [0, 4.75, 0]);

  // rift shards — act three set dressing
  const shards = grp(root, 'rift_shard', [0, 0, 5]);
  [[0, 1.5, 0, 0.5, 1.9, 0.1], [0.7, 0.8, 0.3, 0.3, 1.1, -0.4], [-0.6, 0.6, -0.2, 0.26, 0.9, 0.5]].forEach(([x, y, z, w, h, tilt], i) => {
    add(shards, new THREE.OctahedronGeometry(1, 0), i === 0 ? M.glow : M.graft, `shard_${i + 1}`, [x, y, z], [tilt, i * 0.8, tilt * 0.5], [w, h, w]);
  });
  add(shards, new THREE.TorusGeometry(0.9, 0.035, 6, 28), M.glow, 'shard_ring', [0, 0.05, 0], [HALF_PI, 0, 0]);

  // vent stack — act two set dressing
  const vent = grp(root, 'vent_stack', [4, 0, 5]);
  add(vent, new THREE.CylinderGeometry(0.42, 0.6, 1.5, 14), M.bone, 'vent_lower', [0, 0.75, 0]);
  add(vent, new THREE.CylinderGeometry(0.3, 0.42, 1.4, 14), M.bone, 'vent_upper', [0, 2.2, 0]);
  for (let i = 0; i < 4; i++) band(THREE, c, vent, `vent_band_${i + 1}`, M.graft, 0.56 - i * 0.07, 0.045, [0, 0.4 + i * 0.75, 0], 'y');
  add(vent, new THREE.SphereGeometry(0.26, 14, 12), M.glow, 'vent_glow', [0, 2.9, 0], [0, 0, 0], [1, 0.5, 1]);
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2;
    add(vent, new THREE.BoxGeometry(0.05, 1.0, 0.03), M.glow, `vent_slit_${i + 1}`, [Math.cos(a) * 0.5, 0.7, Math.sin(a) * 0.5], [0, -a, 0]);
  }

  // egg cluster — act one set dressing
  const eggs = grp(root, 'egg_cluster', [8, 0, 5]);
  [[0, 0, 0.42], [0.55, 0.2, 0.3], [-0.5, 0.1, 0.34], [0.15, -0.55, 0.26], [-0.25, 0.55, 0.22]].forEach(([x, z, r], i) => {
    add(eggs, new THREE.SphereGeometry(r, 16, 12), M.membrane, `egg_${i + 1}`, [x, r * 1.1, z], [0, 0, 0], [1, 1.25, 1]);
    add(eggs, new THREE.SphereGeometry(r * 0.45, 12, 10), M.glow, `egg_core_${i + 1}`, [x, r * 1.05, z]);
  });
  add(eggs, new THREE.CylinderGeometry(0.9, 1.05, 0.1, 18), M.chitin, 'egg_bed', [0, 0.05, 0]);

  // lamp stalk — biolum light source
  const lamp = grp(root, 'lamp_stalk', [-5, 0, 5]);
  add(lamp, new THREE.CylinderGeometry(0.09, 0.16, 1.4, 10), M.chitin, 'stalk_lower', [0, 0.7, 0], [0, 0, 0.08]);
  add(lamp, new THREE.CylinderGeometry(0.06, 0.09, 1.2, 10), M.chitin, 'stalk_upper', [-0.14, 1.9, 0], [0, 0, 0.22]);
  add(lamp, new THREE.SphereGeometry(0.27, 18, 14), M.glow, 'lamp_bulb', [-0.36, 2.6, 0]);
  add(lamp, new THREE.SphereGeometry(0.34, 18, 14, 0, Math.PI * 2, 0, HALF_PI), M.bone, 'lamp_hood', [-0.36, 2.64, 0]);
  for (let i = 0; i < 3; i++) spur(lamp, `stalk_thorn_${i + 1}`, M.bone, [0.1 - i * 0.07, 0.5 + i * 0.6, 0], [0, 0, -1.1], 0.03, 0.2);

  // essence crystal — pickup and currency marker
  const gem = grp(root, 'essence_gem', [0, 0, -5]);
  add(gem, new THREE.OctahedronGeometry(0.16, 0), M.glow, 'gem_core', [0, 0.2, 0], [0, 0, 0], [1, 1.4, 1]);
  add(gem, new THREE.TorusGeometry(0.2, 0.014, 6, 20), M.bone, 'gem_ring', [0, 0.2, 0], [HALF_PI, 0, 0]);

  // brood totem — elite / event marker
  const totem = grp(root, 'totem', [4, 0, -5]);
  add(totem, new THREE.CylinderGeometry(0.3, 0.46, 2.6, 8), M.bone, 'totem_shaft', [0, 1.3, 0]);
  add(totem, new THREE.SphereGeometry(0.4, 18, 14), M.membrane, 'totem_sac', [0, 2.8, 0]);
  add(totem, new THREE.SphereGeometry(0.22, 14, 12), M.glow, 'totem_core', [0, 2.8, 0]);
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    spur(totem, `totem_rib_${i + 1}`, M.bone, [Math.cos(a) * 0.42, 2.9, Math.sin(a) * 0.42], [Math.sin(a) * 0.45, 0, -Math.cos(a) * 0.45], 0.06, 0.8);
    add(totem, new THREE.BoxGeometry(0.04, 1.8, 0.03), M.glow, `totem_vein_${i + 1}`, [Math.cos(a) * 0.37, 1.3, Math.sin(a) * 0.37], [0, -a, 0]);
  }
}

const EXT = {
  rail_lance: railLance, spore_launcher: sporeLauncher, needler, arc_caster: arcCaster, ripper,
  spitter, shielder, leaper, swarmling, drone, broodmother,
  matriarch, stalker, core,
  host, props,
};

export const EXT_ENTITIES = Object.keys(EXT);

// register into the shared tables so buildEntity() resolves every key
Object.assign(BUILDERS, EXT);
for (const key of EXT_ENTITIES) if (!ENTITIES.includes(key)) ENTITIES.push(key);
