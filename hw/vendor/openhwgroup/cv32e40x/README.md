# OpenHW Group CORE-V CV32E40X RISC-V IP

CV32E40X is a small and efficient, 32-bit, in-order RISC-V core with a 4-stage pipeline that implements the following instruction set architecture:

* RV32[I|E]
* [A]
* [M|Zmmul]
* Zca_Zcb_Zcmp_Zcmt
* [Zba_Zbb_Zbs|Zba_Zbb_Zbc_Zbs]
* Zicntr
* Zihpm
* Zicsr
* Zifencei
* [Xif]

The CV32E40X core is aimed
at compute intensive applications and offers a general purpose extension interface by which custom instructions
can be added external to the core.

It started its life as a fork of the OpenHW CV32E40P core that in its turn was based on the RI5CY core from
the [PULP platform](https://www.pulp-platform.org/) team.

## Documentation

The CV32E40X user manual can be found in the _docs_ folder and it is
captured in reStructuredText, rendered to html using [Sphinx](https://docs.readthedocs.io/en/stable/intro/getting-started-with-sphinx.html).
These documents are viewable using readthedocs and can be viewed [here](https://docs.openhwgroup.org/projects/cv32e40x-user-manual/en/latest/).

## Verification
The verification environment for the CV32E40X is _not_ in this Repository.

The verification environment for this core as well as other cores in the OpenHW Group CORE-V family is at the
[core-v-verif](https://github.com/openhwgroup/core-v-verif) repository on GitHub.

The Makefiles supported in the **core-v-verif** project automatically clone the appropriate version of the **CV32E40X**  RTL sources.

## Constraints
Example synthesis constraints for the CV32E40X are provided.

## Contributing
We highly appreciate community contributions.
<br><br>To ease our work of reviewing your contributions, please:

* Review [CONTRIBUTING](https://github.com/openhwgroup/cv32e40x/blob/master/CONTRIBUTING.md).
* Create your own fork to commit your changes and then open a Pull Request.
* Split large contributions into smaller commits addressing individual changes or bug fixes. Do not
  mix unrelated changes into the same commit!
* If asked to modify your changes, do fixup your commits and rebase your branch to maintain a
  clean history.

When contributing SystemVerilog source code, please try to be consistent and adhere to [the lowRISC Verilog
coding style guide](https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md).

To get started, please check out the ["Good First Issue"
 list](https://github.com/openhwgroup/cv32e40x/issues?q=is%3Aissue+is%3Aopen+-label%3Astatus%3Aresolved+label%3A%22good+first+issue%22).

## Commit Messages
Please take the time to write meaningful commit messages.
The following are adopted from [lowRISC Ibex](https://github.com/lowrisc/ibex/blob/master/CONTRIBUTING.md):

- Create your branch to commit your changes and then create a Pull Request.
- Separate subject from body with a blank line.
- Limit the subject line to 50 characters.
- Capitalize the subject line.
- Do not end the subject line with a period.
- Use the imperative mood in the subject line.
- Use the present tense ("Add feature" not "Added feature").
- Wrap the body at 72 characters.
- Use the body to explain what and why vs. how.

For a detailed why and how please refer to one of the multiple [resources](https://chris.beams.io/posts/git-commit/) regarding git commit messages.

If you use `vi` for your commit message, consider to put the following snippet inside your `~/.vimrc`:

```
autocmd Filetype gitcommit setlocal spell textwidth=72
```

## Issues and Troubleshooting
If you find any problems or issues with CV32E40X or the documentation, please check out the [issue
 tracker](https://github.com/openhwgroup/cv32e40x/issues) and create a new issue if your problem is
not yet tracked.
