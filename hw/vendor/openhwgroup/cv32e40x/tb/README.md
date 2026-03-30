Running Simulations
==================================
The core repository does not contain any verification or simulation environment.
This is contained in the core-v-verif repository (https://github.com/openhwgroup/core-v-verif).
----------------------------------
Follow these steps to run a simulation:

1. Clone core-v-verif to desired location:

   git clone https://github.com/openhwgroup/core-v-verif.git

2. Go to simulation directory:

   cd core-v-verif/cv32/sim/uvmt_cv32

3. Run simulation and point the core path to this repository. Example:

   make test TEST=hello_world CV_DUT_PATH="/path/to/this/repo/cv32e40x"

