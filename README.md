# Task Runner Comparison

Three ways to drive the same project. In this case, Terraform:

* [`make/`](make/): Make
* [`bash/`](bash/): a Bash-native CLI implementation
* [`just/`](just/): Just examples, including a recipe-first `justfile` and a more Make-like inline Justfile variant

## Options

- [Make](make/README.md)
  Primary interface: `make tf-plan`
  Extra dependency: `make`
  Best fit: well worn task-runner interface, portable conventions
- [Bash](bash/README.md)
  Primary interface: `./bin/tf plan`
  Extra dependency: none beyond Bash
  Best fit: portable, flexible CLI
- [Just](just/README.md)
  Primary interface: `just plan`
  Extra dependency: `just`
  Best fit: more modern developer-facing UX, with both library-backed and inline recipe styles available

## Comparison

- Portability
  Make: strong on Unix-like systems/containers, weaker on Windows without extra setup
  Bash: strong on Unix-like systems, minimal runtime assumptions
  Just: good once `just` is installed, but it adds one more required binary
- Maintainability
  Make: compact when task logic is small, but can get opaque as shell grows inside recipes
  Bash: most explicit and easiest to refactor like normal code
  Just: good when the `justfile` owns the interface and the shell code stays implementation-only
- Troubleshooting / Debugging
  Make: often the hardest to debug because Make, shell, and env resolution are intertwined
  Bash: usually the easiest to debug because the interface is a normal CLI and the logic is plain shell
  Just: better than Make for discovery, but deep failures still end up in shell scripts underneath
- Discoverability
  Make: depends on help implementation and recipe usage
  Bash: depends on how good the CLI help is
  Just: simple day-to-day UX, `just --list` is clean and readable
- Community Support
  Make: very large installed base and long history
  Bash: Bash itself is ubiquitous, but task-runner patterns vary widely
  Just: much smaller ecosystem, but active and focused on developer workflow
- Dependency Footprint
  Make: low on most Unix-like machines
  Bash: lowest of the three
  Just: higher than Bash or Make because `just` must be installed and maintained everywhere
- Expressiveness
  Make: good at simple task graphs and dependencies
  Bash: best for custom CLI behavior and richer argument handling
  Just: best for modern task catalogs, aliases and light orchestration

## Pros And Cons

### Make

**Pros**

* Widely available on developer machines and CI
* Good fit when the workflow is target-oriented and mostly declarative

**Cons**

* Shell quoting, env propagation, and recipe behavior can be harder to reason about
* Argument handling is usually less natural than a real CLI
* Debugging often means understanding both Make semantics and shell semantics at the same time

### Bash

**Pros**

* Most natural place to build an actual CLI with flags, subcommands, and clearer error handling
* Easiest to single-step, log, and troubleshoot
* No extra task-runner dependency beyond Bash itself

**Cons**

* More implementation code to own and maintain.
* You have to build your own command discovery, usage text, and workflow guardrails
* Without discipline, Bash CLIs can drift into ad hoc conventions just as easily as Makefiles

### Just

**Pros**

* Cleanest human-facing UX of the three
* Strong discoverability and onboarding with `just --list`
* Good middle ground when you want recipes up top and implementation details below

**Cons**

* Adds an extra binary that every machine and CI image must carry
* Still needs shell or scripts for non-trivial logic
* Can become hard to maintain if too much real logic is embedded directly in the `justfile`
* Least amount of AI/LLM support

## Practical Guidance

Fastest start with minimal fuss: [Make](make/README.md).

Most explicit and debuggable interface: [Bash](bash/README.md).

Modern day-to-day developer ergonomics and comfortable shipping and maintaining an extra tool: [Just](just/README.md).

in general, the most maintainable long-term approach:

* real implementation logic in scripts
* a thin layer on top

Make brings this out of the box (if you don't go overboard), the Bash example is CLI-first, and the Just example is recipe-first with the workflow owned by the `justfile`.
