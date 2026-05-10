---
name: personal-tasks
description: Personal task manager for Théau. Use when the user asks about tasks, todo items, task summaries, active tasks, completed tasks, Discord task cleanup, white_check_mark reactions, moving tasks to done, or keeping the tasks channel as a dynamic list of remaining tasks.
---

# Personal Tasks

Use this skill to manage Théau's Discord task workflow.

## Channels

Active tasks channel:

- `#✅-tasks`
- ID: `1500624383515820143`

Done tasks channel:

- `#✅-task-done`
- ID: `1501280239979069520`

Logs channel:

- `#🔧-logs`
- ID: `1500624388502978819`

## Channel policy

`#✅-tasks` is dynamic.

It must contain only the current active task messages.

Do not leave:
- old summaries
- duplicate task messages
- user command messages like "Ajoute une tâche ..."
- completed task messages
- cleanup chatter

## Adding tasks

New task additions should be handled by the `dynamic-tasks` hook.

When the user writes in `#✅-tasks`:

```text
Ajoute une tâche ...
Ajoute une tache ...
TODO: ...
task: ...
à faire: ...

the hook should:

create one clean active task message in #✅-tasks;
delete the original user command message;
avoid invoking the model for a normal task add.

If the model sees such a message, do not answer conversationally. Let the hook handle it.

Completed tasks

A task is considered completed when the active task message has a ✅ / :white_check_mark: reaction.

Default behavior:

Copy the completed task to #✅-task-done.
Delete the completed task message from #✅-tasks.
Delete obsolete task summaries or related cleanup chatter in #✅-tasks.
Keep only remaining active tasks in #✅-tasks.

Do not ask for confirmation before moving completed tasks. This is the default behavior.

Daily recall

Task recall must run only once per day.

The daily job should:

read recent messages in #✅-tasks;
detect task messages with ✅ reactions;
move completed tasks to #✅-task-done;
delete completed task messages from #✅-tasks;
remove duplicate or obsolete summaries;
leave #✅-tasks as a clean active task list;
send any cleanup summary to #🔧-logs, not to #✅-tasks.
Commands

Read recent active tasks:

openclaw message read \
  --channel discord \
  --target channel:1500624383515820143 \
  --limit 100

Check reactions on a message:

openclaw message reactions \
  --channel discord \
  --target channel:1500624383515820143 \
  --message-id MESSAGE_ID

Move a completed task to done:

openclaw message send \
  --channel discord \
  --target channel:1501280239979069520 \
  --message "✅ Done: TASK_TEXT"

Delete the original task message:

openclaw message delete \
  --channel discord \
  --target channel:1500624383515820143 \
  --message-id MESSAGE_ID
Response style

For task summaries:

keep it short;
show only active tasks;
mention completed tasks only in #✅-task-done or #🔧-logs;
do not pollute #✅-tasks with long explanations.
