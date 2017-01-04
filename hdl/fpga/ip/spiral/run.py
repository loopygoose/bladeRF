# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

#lib_path = join(root, "lib")
#misc_path = join(root, "misc")
drl_path = join(root, "..\\drl\\synthesis")
src_path = join(root, "synthesis")
tb_path = join(root, "simulation")
#fft_sim_path = join(root, "..\\altera\\fft\\fft\\simulation\\submodules\\");
#fft_path = join(root, "..\\altera\\fft\\fft\\synthesis\\");
#dpram_path = join(root, "..\\altera\\dpram");
#altera_sim_path = "C:\\altera\\15.0\\quartus\\eda\\sim_lib\\"


ui = VUnit.from_argv()
ui.add_osvvm()

ui.enable_location_preprocessing()
ui.enable_check_preprocessing()

#altera_mf = ui.add_library("altera_mf");

#altera_mf.add_source_files(join(altera_sim_path, "altera_mf.v"))
#altera_mf.add_source_files(join(altera_sim_path, "altera_mf_components.vhd"))

#sim = ui.add_library("sim");

#sim.add_source_files(join(altera_sim_path, "altera_primitives.v"))
#sim.add_source_files(join(altera_sim_path, "220model.v"))
#sim.add_source_files(join(altera_sim_path, "sgate.v"))
#sim.add_source_files(join(altera_sim_path, "altera_lnsim.sv"))
#sim.add_source_files(join(altera_sim_path, "cycloneive_atoms.v"))

spiral = ui.add_library("spiral")

spiral.add_source_files(join(src_path, "*.v"))
spiral.add_source_files(join(src_path, "*.vhd"))
spiral.add_source_files(join(tb_path, "*.vhd"))
spiral.add_source_files(join(drl_path, "btle_common.vhd"))
spiral.add_source_files(join(drl_path, "btle_iq_streamer.vhd"))
#zcold.add_source_files(join(misc_path, "*.vhdl"))
#zcold.add_source_files(join(src_path, "*.vhdl"))
#zcold.add_source_files(join(tb_path, "*.vhdl"))

ui.main()
