STEPS = step0_repl step1_read_print step2_eval step3_env step4_if_fn_do
FLAGS = -opt:0

all: $(STEPS)

clean:
	$(RM) step* mal

step%: src/step%
	odin build $< -out:$@ $(FLAGS)
