build:
	verilator --binary --timing -j 0 \
	../rtl/hdmi_timing.sv ../rtl/hdmi_pattern.sv \
	../rtl/hdmi_tmds_encoder.sv hdmi_video_tb.sv \
	../lint/hdmi.vlt \
	tb.vlt \
	--top-module hdmi_video_tb

run: build
	./obj_dir/Vhdmi_video_tb

all: run
