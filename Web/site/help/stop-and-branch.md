# Stop and Branch cards

Most cards in a rotation are actions. Two special cards change the *flow* of the priority list instead.

## Stop

A **Stop** card ends the priority list. If RM reaches a Stop whose conditions match, it does not look at any card below it.

```diagram
 1. Spell: Fireball    if target has no Ignite
 2. STOP               if I am moving
 3. Spell: Frostbolt          ← skipped while moving
 4. Spell: Arcane Missiles    ← skipped while moving
```

Use it to say "in this situation, none of the rest applies": while channelling a spell you do not want interrupted, while out of combat, while wanding, and so on.

Things a Stop does **not** affect:

- [Cooldowns](/help/cooldowns) are still checked and highlighted on their own.
- The **implicit Attack** fallback can still be recommended after a Stop, unless you tick **Also suppress implicit Attack** on that Stop card. Casters often add a final, always-true Stop with this ticked so they are never told to melee.

> **Note:** If a Stop's condition cannot be evaluated (the game did not provide the data), RM treats the Stop as applying and also suppresses Attack. It prefers recommending nothing to recommending the wrong thing.

Stop is only available in the ordered rotation, not in cooldowns.

## Branch

A **Branch** splits the rest of the list into two arms based on a condition, its *guard*.

```diagram
 1. Spell: Shield Block
 2. BRANCH  if 3 or more enemies are near me
      False arm (left, red)           True arm (right, green)
        a. Spell: Shield Slam           a. Spell: Thunder Clap
        b. Spell: Revenge               b. Spell: Revenge
                                        c. Spell: Cleave
 3. Spell: Heroic Strike        ← both arms rejoin here
```

How it works:

- When RM reaches the branch it evaluates the guard and walks **one** arm: True or False.
- After finishing that arm without finding anything, it **rejoins** the cards that follow the branch.
- A Stop inside an arm ends the whole list, not just the arm.

In the editor, the **False** arm is on the left with red connectors and the **True** arm is on the right with green ones. When you insert a branch, every card after it moves into its True arm; drag cards into the False arm as needed.

### Branch modes

The mode pill on a branch cycles through three settings:

| Mode | Behaviour |
|---|---|
| **Evaluate condition** | Normal: check the guard, then follow True or False. |
| **Always true** | Skip the guard and always take the True arm. |
| **Always false** | Skip the guard and always take the False arm. |

The forced modes are handy while testing, or for temporarily switching off part of a rotation without deleting it. Cards in the arm that can no longer be reached are shown in grey. RM still validates them when you Apply.

### Editing branches

- Click the guard text to edit the branch condition.
- The branch icon folds both arms out of view; click **True** or **False** to fold just that arm. Folding never changes the rotation.
- Moving a branch always carries both its arms.
- Branches can be nested up to 16 levels deep.
