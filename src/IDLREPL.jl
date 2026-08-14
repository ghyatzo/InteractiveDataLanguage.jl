import REPL: respond, LineEdit, mode_keymap

# Install an `IDL> ` prompt in the current julia REPL.
# Enter with `>` on an empty julia prompt,
# exit with backspace on an empty input, like the shell and help modes.
function idlrepl()
	# no REPL available in non-interactive sessions
	!isdefined(Base, :active_repl) && return nothing

	repl = Base.active_repl
	main_mode = repl.interface.modes[1]

	prompt = LineEdit.Prompt("IDL> ";
		prompt_prefix=Base.text_colors[:blue],
		prompt_suffix=Base.text_colors[:white],
	)

	prompt.on_done = respond(repl, prompt) do line
		isempty(strip(line)) || idlrun(line)
		nothing
	end

	# replace an existing IDL prompt if idlrepl() is called twice
	i_mode = find_prompt_in_modes(repl.interface.modes, "IDL> ")
	if i_mode < 1
		push!(repl.interface.modes, prompt)
	else
		repl.interface.modes[i_mode] = prompt
	end

	# share the julia prompt history
	hp = main_mode.hist
	hp.mode_mapping[:idl] = prompt
	prompt.hist = hp

	# `>` on an empty julia prompt enters the IDL mode
	idl_keymap = Dict{Any,Any}(
		'>' => function (s, args...)
			if isempty(s)
				if !haskey(s.mode_state, prompt)
					s.mode_state[prompt] = LineEdit.init_state(repl.t, prompt)
				end
				LineEdit.transition(s, prompt)
			else
				LineEdit.edit_insert(s, '>')
			end
		end,
	)

	_, skeymap = LineEdit.setup_search_keymap(hp)
	mk = mode_keymap(main_mode)

	prompt.keymap_dict = LineEdit.keymap([
		skeymap, mk, LineEdit.history_keymap,
		LineEdit.default_keymap, LineEdit.escape_defaults,
	])

	main_mode.keymap_dict = LineEdit.keymap_merge(main_mode.keymap_dict, idl_keymap)
	return nothing
end

function find_prompt_in_modes(modes, name)
	for (i, mode) in enumerate(modes)
		if :prompt in fieldnames(typeof(mode)) && mode.prompt == name
			return i
		end
	end
	return -1
end
