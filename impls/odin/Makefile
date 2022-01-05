STEPS = step0_repl step1_read_print

all: $(STEPS)

clean:
	$(RM) step* mal

step%: src/step%
	odin build $< -out:$@
