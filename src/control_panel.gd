extends CanvasLayer
class_name ControlPanel

@export var quadruped: Quadruped

var _overlay: _LimbOverlay

func _ready() -> void:
	_overlay = _LimbOverlay.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.panel = self

func _process(_delta: float) -> void:
	if _overlay:
		_overlay.queue_redraw()


class _LimbOverlay extends Control:
	var panel: ControlPanel

	const R := 26.0
	const GAP := 10.0
	const MARGIN := 12.0
	const TITLE_H := 18.0
	const EXT_LABEL_H := 16.0
	const FONT_SIZE_TITLE := 11
	const FONT_SIZE_LABEL := 12
	const FONT_SIZE_EXT := 10
	const MAX_EXT := 2.0
	const ARC_STEPS := 48

	const C_GROUNDED  := Color(0.20, 0.85, 0.30, 0.95)
	const C_AIRBORNE  := Color(0.90, 0.22, 0.22, 0.95)
	const C_EXT_ARC   := Color(1.00, 1.00, 1.00, 0.90)
	const C_OUTLINE   := Color(1.00, 1.00, 1.00, 0.35)
	const C_BG        := Color(0.05, 0.05, 0.05, 0.55)
	const C_TEXT      := Color(1.00, 1.00, 1.00, 1.00)
	const C_EXT_TEXT  := Color(0.80, 0.80, 0.80, 1.00)

	const GRAPH_W       := 80.0
	const GRAPH_H       := 28.0
	const GRAPH_ROW_GAP := 5.0
	const GRAPH_LABEL_W := 22.0
	const GRAPH_COL_GAP := 5.0
	const GRAPH_STEPS   := 48
	const C_CURVE_Y     := Color(0.35, 0.85, 1.00, 0.90)
	const C_CURVE_X     := Color(1.00, 0.80, 0.25, 0.90)
	const C_GRAPH_BG    := Color(0.00, 0.00, 0.00, 0.40)
	const C_STEP_LINE   := Color(1.00, 1.00, 1.00, 0.50)
	const C_STEP_DOT    := Color(1.00, 1.00, 1.00, 1.00)

	func _draw() -> void:
		if not panel or not is_instance_valid(panel.quadruped):
			return
		var q := panel.quadruped
		if not is_instance_valid(q.shoulder) or not is_instance_valid(q.pelvis):
			return

		var limbs: Array = [
			["FL", q.shoulder.left_limb],
			["FR", q.shoulder.right_limb],
			["BL", q.pelvis.left_limb],
			["BR", q.pelvis.right_limb],
		]

		_draw_curves_panel(10.0, 10.0, limbs, q)

		var cell_w := R * 2.0
		var cell_h := R * 2.0 + EXT_LABEL_H
		var panel_w := MARGIN * 3.0 + cell_w * 2.0
		var panel_h := MARGIN * 2.0 + TITLE_H + (cell_h + GAP) * 2.0 - GAP
		var vp_w := get_viewport_rect().size.x
		var px := vp_w - panel_w - 10.0
		var py := 10.0

		var font := ThemeDB.fallback_font

		# Background
		draw_rect(Rect2(px, py, panel_w, panel_h), C_BG, true)
		draw_rect(Rect2(px, py, panel_w, panel_h), C_OUTLINE, false, 1.5)

		# Title
		var title := "LIMBS"
		var title_x := px + panel_w * 0.5 - font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_TITLE).x * 0.5
		draw_string(font, Vector2(title_x, py + FONT_SIZE_TITLE + 3.0), title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_TITLE, C_TEXT)

		for i in 4:
			var label: String = limbs[i][0]
			var limb: Limb = limbs[i][1]
			if not is_instance_valid(limb):
				continue

			var col := i % 2
			var row := i / 2
			var cx := px + MARGIN + R + col * (cell_w + MARGIN)
			var cy := py + TITLE_H + MARGIN + R + row * (cell_h + GAP)

			var grounded := !limb.stepping
			var ext := 0.0
			if is_instance_valid(limb.root) and is_instance_valid(limb.target) \
					and limb.root.is_inside_tree() and limb.target.is_inside_tree():
				ext = limb.calculate_limb_extension()

			var fill := C_GROUNDED if grounded else C_AIRBORNE
			draw_circle(Vector2(cx, cy), R, fill)
			draw_arc(Vector2(cx, cy), R, 0.0, TAU, ARC_STEPS, C_OUTLINE, 1.5)

			# Extension arc (white ring segment, clockwise from top)
			var ratio := clampf(ext / MAX_EXT, 0.0, 1.0)
			if ratio > 0.01:
				draw_arc(Vector2(cx, cy), R - 5.0,
						-PI * 0.5, -PI * 0.5 + TAU * ratio,
						ARC_STEPS, C_EXT_ARC, 3.5)

			# Limb label inside circle
			var lbl_sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_LABEL)
			draw_string(font, Vector2(cx - lbl_sz.x * 0.5, cy + lbl_sz.y * 0.35),
					label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_LABEL, C_TEXT)

			# Extension value below circle
			var ext_str := "%.2f" % ext
			var ext_color := C_EXT_TEXT if ext <= 0.0 else Color(1.0, 0.85, 0.3, 1.0)
			var ext_sz := font.get_string_size(ext_str, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_EXT)
			draw_string(font, Vector2(cx - ext_sz.x * 0.5, cy + R + EXT_LABEL_H - 2.0),
					ext_str, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_EXT, ext_color)

	func _draw_curves_panel(px: float, py: float, limbs: Array, q: Quadruped) -> void:
		var font := ThemeDB.fallback_font
		var col_gap := GRAPH_COL_GAP
		var panel_w := MARGIN * 2.0 + GRAPH_LABEL_W + col_gap + GRAPH_W * 3.0 + col_gap * 2.0
		var panel_h := MARGIN * 2.0 + TITLE_H + FONT_SIZE_EXT + 3.0 + limbs.size() * (GRAPH_H + GRAPH_ROW_GAP) - GRAPH_ROW_GAP

		draw_rect(Rect2(px, py, panel_w, panel_h), C_BG, true)
		draw_rect(Rect2(px, py, panel_w, panel_h), C_OUTLINE, false, 1.5)

		var title := "STEP CURVES"
		draw_string(font, Vector2(px + MARGIN, py + MARGIN + FONT_SIZE_TITLE),
				title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_TITLE, C_TEXT)

		var header_y := py + MARGIN + TITLE_H
		var col_labels := ["HEIGHT", "EASE", "PATH"]
		var col_colors := [C_CURVE_Y, C_CURVE_X, C_STEP_DOT]
		var gx_y0 := px + MARGIN + GRAPH_LABEL_W + col_gap
		for ci in 3:
			var gx := gx_y0 + ci * (GRAPH_W + col_gap)
			var lbl = col_labels[ci]
			var lsz = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_EXT)
			draw_string(font, Vector2(gx + GRAPH_W * 0.5 - lsz.x * 0.5, header_y + FONT_SIZE_EXT),
					lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_EXT, col_colors[ci])

		for i in limbs.size():
			var label: String = limbs[i][0]
			var limb: Limb = limbs[i][1]
			if not is_instance_valid(limb):
				continue

			var ry := py + MARGIN + TITLE_H + FONT_SIZE_EXT + 3.0 + i * (GRAPH_H + GRAPH_ROW_GAP)

			var is_current = q.gait and not q.gait.cycle.is_empty() and q.gait.cycle[q._cycle_index] == i
			if is_current and q.gait.cycle_step_time > 0.0:
				var flash := clampf(q._cycle_timer / q.gait.cycle_step_time, 0.0, 1.0)
				var row_w := GRAPH_LABEL_W + GRAPH_COL_GAP + GRAPH_W * 3.0 + GRAPH_COL_GAP * 2.0
				draw_rect(Rect2(px + MARGIN, ry, row_w, GRAPH_H),
						Color(0.2, 0.85, 0.3, flash * 0.25), true)

			var lbl_sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_EXT)
			draw_string(font, Vector2(px + MARGIN, ry + GRAPH_H * 0.5 + lbl_sz.y * 0.35),
					label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_EXT, C_TEXT)

			var gx_y := px + MARGIN + GRAPH_LABEL_W + col_gap
			var gx_x := gx_y + GRAPH_W + col_gap
			var gx_combined := gx_x + GRAPH_W + col_gap
			var cur_t := limb.step_t if limb.stepping else -1.0
			var gait: Gait = limb.gait

			_draw_mini_curve(gx_y, ry, gait.curve_y if gait else null,
					true, cur_t, C_CURVE_Y, font)
			_draw_mini_curve(gx_x, ry, gait.curve_x if gait else null,
					false, cur_t, C_CURVE_X, font)
			_draw_combined_curve(gx_combined, ry,
					gait.curve_x if gait else null,
					gait.curve_y if gait else null,
					cur_t)

	func _draw_mini_curve(gx: float, gy: float, curve: Curve,
			is_y: bool, cur_t: float, color: Color, font: Font) -> void:
		draw_rect(Rect2(gx, gy, GRAPH_W, GRAPH_H), C_GRAPH_BG, true)
		draw_rect(Rect2(gx, gy, GRAPH_W, GRAPH_H), C_OUTLINE, false, 1.0)

		var pts: PackedVector2Array = []
		for s in GRAPH_STEPS + 1:
			var t := float(s) / float(GRAPH_STEPS)
			var v: float
			if curve:
				v = curve.sample(t)
			elif is_y:
				v = sin(t * PI)
			else:
				v = t
			pts.append(Vector2(gx + t * GRAPH_W, gy + GRAPH_H - clampf(v, 0.0, 1.0) * GRAPH_H))
		if pts.size() > 1:
			draw_polyline(pts, color, 1.5)

		if cur_t >= 0.0:
			var dot_x := gx + cur_t * GRAPH_W
			var v: float
			if curve:
				v = curve.sample(cur_t)
			elif is_y:
				v = sin(cur_t * PI)
			else:
				v = cur_t
			var dot_y := gy + GRAPH_H - clampf(v, 0.0, 1.0) * GRAPH_H
			draw_line(Vector2(dot_x, gy), Vector2(dot_x, gy + GRAPH_H), C_STEP_LINE, 1.0)
			draw_circle(Vector2(dot_x, dot_y), 3.0, C_STEP_DOT)

	func _draw_combined_curve(gx: float, gy: float, curve_x: Curve, curve_y: Curve, cur_t: float) -> void:
		draw_rect(Rect2(gx, gy, GRAPH_W, GRAPH_H), C_GRAPH_BG, true)
		draw_rect(Rect2(gx, gy, GRAPH_W, GRAPH_H), C_OUTLINE, false, 1.0)

		var pts: PackedVector2Array = []
		for s in GRAPH_STEPS + 1:
			var t := float(s) / float(GRAPH_STEPS)
			var vx := curve_x.sample(t) if curve_x else t
			var vy := curve_y.sample(t) if curve_y else sin(t * PI)
			pts.append(Vector2(gx + clampf(vx, 0.0, 1.0) * GRAPH_W,
					gy + GRAPH_H - clampf(vy, 0.0, 1.0) * GRAPH_H))
		if pts.size() > 1:
			draw_polyline(pts, C_STEP_DOT, 1.5)

		if cur_t >= 0.0:
			var vx := curve_x.sample(cur_t) if curve_x else cur_t
			var vy := curve_y.sample(cur_t) if curve_y else sin(cur_t * PI)
			draw_circle(Vector2(gx + clampf(vx, 0.0, 1.0) * GRAPH_W,
					gy + GRAPH_H - clampf(vy, 0.0, 1.0) * GRAPH_H), 3.0, C_STEP_DOT)
