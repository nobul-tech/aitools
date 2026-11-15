## 8. Review and refine the draft before writing the file

Attack the draft in thinking and refine it until the attacks fail. Write the
file only then.

- **Check it against its sources**: line by line, against the conversation
  and every source from item 3. Fix every line they do not support.
- **Red team it**: argue against the draft as an opponent would, and find the
  line that is wrong, missing or open to misreading.
- **Pre-mortem it**: assume the work has already failed in use, list the
  reasons, and fix each one in the draft.
- **Check key assumptions**: list what the draft assumes. For each, ask what
  breaks if it is false, then resolve it or surface it (items 4 and 5).
- **Argue the other side**: for each choice in the draft, make the strongest
  case for the option you rejected. Keep your choice only if it still wins.
- **Look for overcorrection**: test each earlier correction you applied for
  being applied more broadly than it was meant.
- **Repeat until clean**: run passes until one finds nothing to fix.

Adopted from: adversarial review — red teaming and devil's advocacy
(military and intelligence analysis), the pre-mortem (Gary Klein) and the key
assumptions check (structured analytic techniques).

## 9. Review the written files, one reader at a time

Read each written file from disk, line by line, once for each reader, and fix
what that reader would trip on.

- **Read what was written**: re-read the file from disk, not the draft you
  meant to write. Check that it matches the reviewed draft from item 8 and
  the sources from item 3, with nothing dropped, compressed or added.
- **Name the readers**: list who and what consumes the file: the commander,
  an agent following it, a delegate with none of this session's context, and
  any script, hook or tool that parses it.
- **One pass per reader**: read the whole file as that reader, with only what
  that reader will have.
- **Ask that reader's questions**: can they act on each line? Is a term
  undefined for them? Is a path, name or number one they cannot resolve?
- **Fix and re-read**: fix each defect in the file, then re-read the changed
  lines as every reader.
- **Repeat until clean**: run rounds until a full round finds nothing to fix.

Adopted from: perspective-based reading (Victor Basili and colleagues,
software inspection): each review pass reads the work from one stakeholder's
perspective and asks that perspective's questions.
