# Protecting the work

Notes for the author, not for users of the pipeline. Delete this file before
publishing if you prefer.

## What does not work

**Docker.** `docker save` plus `tar xf` gives anyone your `.py` files verbatim.
See [`docker.md`](docker.md).

**Obfuscation and bytecode.** Shipping `.pyc` instead of `.py`: `decompyle3` and
`uncompyle6` reverse it. Name-mangling obfuscators: readable after an hour with a
debugger. Both make your code harder for *you* to maintain and harder for
reviewers to trust, which costs you citations.

**Compiling to native code** (Nuitka, Cython `--embed`, MATLAB Compiler) is the
only technical measure that raises the bar meaningfully — a `.so` is genuinely
hard to read. But it does not hide the *method*, which is what a competitor
actually wants, and your paper describes the method anyway. It also breaks
reproducibility, and reviewers increasingly ask for runnable code.

None of these stop the realistic threat, which is not someone stealing your
source. It is someone reading your paper, reimplementing the idea in a week, and
publishing first without citing you.

## What does work

**1. Time the release.** Keep the repository private until the paper is
accepted, then publish the tagged commit that matches it. This is normal, and no
reviewer objects to "code will be released upon acceptance" as long as you mean
it. It is by far the biggest lever you have.

**2. Make citation the path of least resistance.** `CITATION.cff` puts a "Cite
this repository" button on the GitHub page. State the citation requirement in
the README's first screen. Get a DOI by connecting the repo to Zenodo, so the
code is citable independently of the paper. People cite what is easy to cite.

**3. Pick a licence that matches your intent.** The licence is the only
enforceable thing in this list.

| Licence | Someone can... | Use when |
|---|---|---|
| MIT / BSD-3 | do anything, including sell a closed product, with attribution only | you want maximum uptake and citations, and do not mind commercial use |
| **GPL-3.0** | use and modify freely, but must open-source anything they distribute that builds on it | you want it used and cited in academia, but not quietly absorbed into a closed commercial product |
| CC BY-NC 4.0 or a custom academic licence | use it for research only; commercial use requires a separate agreement | you or your institution intend to commercialise. Not an open-source licence; some users and journals will avoid it |

GPL-3.0 is the usual fit for the concern "I do not want a company taking this".
Talk to your university's tech transfer office before choosing anything
non-standard — if the work was funded by a grant, the licence may not be
entirely yours to pick.

**4. Keep the git history clean.** `git log` reveals directory structures,
collaborator names and dataset paths. Publish from a fresh repository with a
single initial commit rather than pushing your working history. This repository
is a fresh directory, so an `git init` here gives you exactly that.

## Before you push — checklist

- [ ] `config/config.sh` is untracked (`.gitignore` covers it — verify with `git status`)
- [ ] no `.csv`, `.xlsx`, `.txt` containing subject ids or clinical variables
- [ ] no `license.txt` for FreeSurfer or any other tool
- [ ] no absolute paths naming colleagues: `grep -rn "/ifs/\|/ifshome/\|/scratch/" .`
- [ ] no cluster hostnames or internal URLs
- [ ] `LICENSE` says what you actually mean
- [ ] `CITATION.cff` has the right author list, ORCID and paper reference
- [ ] the third-party attribution in `NOTICE` is accurate and compatible with your licence choice

Run the whole check at once:

```bash
grep -rniE "/ifs/|/ifshome/|/scratch/faculty|\.ini\.usc\.edu|license\.txt" \
  --exclude-dir=.git --exclude-dir=docs .
```

Anything it prints outside `docs/` needs to go.
