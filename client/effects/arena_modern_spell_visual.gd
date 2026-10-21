class_name ArenaModernSpellVisual
extends ArenaLegacySpellVisual
## Lightweight modernization: original animation and one shared fragment shader.
func configure(spell: Dictionary) -> void:
	super.configure(spell)
	concept = "ao_atlas_finish"
	set_meta("modern_fx", true)
	if sprite != null: ArenaSpellFinish.apply(sprite)
