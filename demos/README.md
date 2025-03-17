# Running OGHarn Demos
### Step 1: Installation
- Ensure all dependencies listed in the root [README](../README.md) are installed.
- Set the environment using `/extras/set_env.sh`. The binaries for Multiplier and AFL++ should be in the system path.

### Step 2: Build the necessary resources
Navigate to any of the libraries listed in the `/demos` directory and run `make all`. This builds:

- Dynamically linked library instrumented with AFL++ and ASAN/UBSAN for harness generation.
- Statically linked library instrumented with AFL++ for fuzzing.
- If applicable, a build of the library to be used for indexing with Multiplier.
- Multiplier-produced index of the library for static analysis during harness generation.


### Step 3: Begin harness generation
Run `run_ogharn.sh`. This will begin harness generation for the corresponding demo. In some cases OGHarn will quickly discover valid harnesses for libraries, while other libraries will take more time. This is dependent on the size and complexity of the library. Some libraries that demonstrate OGHarn's ability to quickly discover interesting fuzzing harnesses are: [cjson](./cjson), [faup](./faup), [lexbor](./lexbor), [cgltf](./cgltf), [pcre2](./pcre2/), and [ucl](./ucl).

### Step 4: Post processing
In order to get a set of harnesses that exercise deep, unique coverage, allowing OGHarn to run until it has exhausted all potential harnessing routines is recommended. This typically takes less than 24 hours. For the purpose of testing, terminating harness generation after OGHarn begins to report successful harnesses is also possible.

Debugging information and final harnesses will be stored in the output directory provided to OGHarn with the `-o` argument. Final harnesses will be ranked according to the number of unique edges they reach compared to all other harnesses in the corpus.

Run `make harness_fuzz HARNESS_NUMBER=<desired harness number> OUT=<output directory>` to build a final harness for fuzzing. The binary will be stored in the `bin` directory of the corresponding demo.



