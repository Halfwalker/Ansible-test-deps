https://serverfault.com/questions/991605/ansible-proper-method-for-handling-roles-tasks-dependencies

### Ansible - Proper method for handling roles, tasks, dependencies ?
Related to [How to keep ansible role from running multiple times when listed as a dependency?](https://stackoverflow.com/questions/54333423/how-to-keep-ansible-role-from-running-multiple-times-when-listed-as-a-dependency)

This is a long post/question.  TL;DR - what's the right way to setup tagging of roles and tasks such that dependencies will work correctly without roles being run multiple times.

I've been having some trouble with getting playbooks to play well with tags and dependencies.  In general, I want a playbook with a bunch of roles, (each with some set of dependencies) to "work cleanly".  This alone is fairly easy to set up, and works well when using all the roles in the whole playbook.  The roles with dependencies can be defined in any order in the playbook, and those dependencies ensure that they're run in the correct order.  Of course roles without dependencies will run in the order they appear in the playbook roles: section.

But there are times when one wants to just run a subset of the roles, and then it falls apart, with some roles being run multiple times, and in weird orders.

So I've built a test setup, with 4 roles (**A B C D**), and a playbook with multiple tagging methods used.  Actually, it's 4 roles with bare untagged tasks, and 4 roles with tagged tasks ... plus a role named 'z' with no tasks, just a dependency for all the other roles.  They look like this :

```
Role name    Dependencies
----------   ------------
a_tagged     none
b_tagged     a_tagged
c_tagged     b_tagged
d_tagged     c_tagged b_tagged a_tagged
z_tagged     a_tagged b_tagged c_tagged d_tagged
a_untagged   none
b_untagged   a_untagged
c_untagged   b_untagged
d_untagged   c_untagged b_untagged a_untagged
z_untagged   a_untagged b_untagged c_untagged d_untagged
```

Each role ***tasks/main.yml*** looks like this - in this example role "**b_tagged**" has just one task, and that task is tagged with "**tags: b**"

***./roles/b_tagged/tasks/main.yml***
```
---
- debug: msg="Role B tagged"
  tags: b
```
and the associated ***meta/main.yml*** like this, so role **b_tagged** depends on role **a_tagged** :

***./roles/b_tagged/meta/main.yml***
```
---
dependencies:
  - { role: a_tagged }
```
The corresponding **b_untagged** style tasks are identical, but without the "**tags:**" line in the task.

The desired result is for the roles to execute in the order **A B C D** and each one runs only once, like this :
```
    "msg": "Role A ..."
    "msg": "Role B ..."
    "msg": "Role C ..."
    "msg": "Role D ..."
 ```
To provide for the minimal output only showing the debug msg: output, the script "***test.sh***" just runs ansible-playbook as follows.  Wherever you see ***test.sh*** it's simply running this command.

`ANSIBLE_STDOUT_CALLBACK=minimal ansible-playbook -i hosts test.yml $@ -- | egrep -v "{|}"`

There are 4 main scenarios for running the plays ...

- Run every role in each play, default typical use
    `./test.sh`

- Run every role in each play, using the 'z' tag to select every role/task.
Remember, the 'z' role just has all the other roles as dependencies
    `./test.sh --tags 'z'`

- Run each play for only the 'c' tagged roles/tasks
this should only run roles **A B C**
    `./test.sh --tags 'c'`

- Run each play for only the 'b' and 'c' tagged roles/tasks
this should only run roles **A B C**
    `./test.sh --tags 'b,c'`

Each play in the playbook file ***test.yml*** is of this form : (this is the 1st one)

***./test.yml***
```
###########################################################################################
# roles with NO tags and tasks WITH tags, roles defined in reverse order from dependencies.
- hosts: localhost
  gather_facts: false
  become: no

  pre_tasks:
    - debug:
        msg: "=============== untagged roles z d c b a tagged tasks reverse ========"
      tags: always

  roles:
    - role: z_tagged
    - role: d_tagged
    - role: c_tagged
    - role: b_tagged
    - role: a_tagged
###########################################################################################
```
Since only the role definitions change for each playbook (and the **msg:** string) that's all that's listed here for the other plays in the ***test.yml*** playbook file
```
* roles with NO tags and tasks with NO tags, roles defined in reverse order from dependencies
    - role: z_untagged
    - role: d_untagged
    - role: c_untagged
    - role: b_untagged
    - role: a_untagged

* roles WITH tags and tasks WITH tags, roles defined in correct order from dependencies
    - { role: a_tagged, tags: a }
    - { role: b_tagged, tags: b }
    - { role: c_tagged, tags: c }
    - { role: d_tagged, tags: d }
    - { role: z_tagged, tags: z }

* roles WITH tags and tasks WITH tags, roles defined in reverse order from dependencies
    - { role: z_tagged, tags: z }
    - { role: d_tagged, tags: d }
    - { role: c_tagged, tags: c }
    - { role: b_tagged, tags: b }
    - { role: a_tagged, tags: a }

* roles WITH tags and tasks with NO tags, roles defined in correct order from dependencies
    - { role: a_untagged, tags: a }
    - { role: b_untagged, tags: b }
    - { role: c_untagged, tags: c }
    - { role: d_untagged, tags: d }
    - { role: z_untagged, tags: z }

* roles WITH tags and tasks with NO tags, roles defined in reverse order from dependencies
    - { role: z_untagged, tags: z }
    - { role: d_untagged, tags: d }
    - { role: c_untagged, tags: c }
    - { role: b_untagged, tags: b }
    - { role: a_untagged, tags: a }
```
Running the 4 scenarios above produces the following output.

`./test.sh`
Regardless of whether the individual tasks are tagged or not, (so long as the roles do not have tags) results in the correct output (first two plays).  If the roles **DO** have tags, then the roles are run multiple times (as seen in the next 4 plays), the order depending on the order in which they are defined in the play.

Correct example `- role: a_tagged` or `- role: a_untagged` order of roles does not matter
```
"msg": "=============== untagged roles z d c b a tagged tasks reverse ========"
"msg": "Role A tagged"
"msg": "Role B tagged"
"msg": "Role C tagged"
"msg": "Role D tagged"
"msg": "=============== untagged roles z d c b a untagged tasks reverse ======"
"msg": "Role A untagged"
"msg": "Role B untagged"
"msg": "Role C untagged"
"msg": "Role D untagged"
"msg": "=============== tagged roles a b c d z tagged tasks =================="
"msg": "Role A tagged"
"msg": "Role A tagged"
"msg": "Role B tagged"
"msg": "Role B tagged"
"msg": "Role C tagged"
"msg": "Role C tagged"
"msg": "Role D tagged"
"msg": "Role D tagged"
"msg": "=============== tagged roles z d c b a tagged tasks reverse =========="
"msg": "Role A tagged"
"msg": "Role B tagged"
"msg": "Role C tagged"
"msg": "Role D tagged"
"msg": "Role D tagged"
"msg": "Role C tagged"
"msg": "Role B tagged"
"msg": "Role A tagged"
"msg": "=============== tagged roles a b c d z untagged tasks ================"
"msg": "Role A untagged"
"msg": "Role A untagged"
"msg": "Role B untagged"
"msg": "Role B untagged"
"msg": "Role C untagged"
"msg": "Role C untagged"
"msg": "Role D untagged"
"msg": "Role D untagged"
"msg": "=============== tagged roles z d c b a untagged tasks reverse ========"
"msg": "Role A untagged"
"msg": "Role B untagged"
"msg": "Role C untagged"
"msg": "Role D untagged"
"msg": "Role D untagged"
"msg": "Role C untagged"
"msg": "Role B untagged"
"msg": "Role A untagged"
```

`./test.sh --tags 'z'`
When using the **'z'** tag to select all the roles/tasks, *only* the plays with roles that had **tags:** in their definition produced the correct output.  If the role wasn't tagged, then the tasks in that role never execute, *regardless* of whether they're tagged or not.

Correct example `- { role: a_tagged, tags: a }` or `- { role: a_untagged, tags: a }` order of roles does not matter
```
"msg": "=============== untagged roles z d c b a tagged tasks reverse ========"
"msg": "=============== untagged roles z d c b a untagged tasks reverse ======"
"msg": "=============== tagged roles a b c d z tagged tasks =================="
"msg": "Role A tagged"
"msg": "Role B tagged"
"msg": "Role C tagged"
"msg": "Role D tagged"
"msg": "=============== tagged roles z d c b a tagged tasks reverse =========="
"msg": "Role A tagged"
"msg": "Role B tagged"
"msg": "Role C tagged"
"msg": "Role D tagged"
"msg": "=============== tagged roles a b c d z untagged tasks ================"
"msg": "Role A untagged"
"msg": "Role B untagged"
"msg": "Role C untagged"
"msg": "Role D untagged"
"msg": "=============== tagged roles z d c b a untagged tasks reverse ========"
"msg": "Role A untagged"
"msg": "Role B untagged"
"msg": "Role C untagged"
"msg": "Role D untagged"
```

`./test.sh --tags 'c'`
Running just a selected role (and its dependencies) the only correct output was from having the roles tagged and the tasks **NOT** tagged (last two plays).

Correct example `- { role: a_untagged, tags: a }` order of roles does not matter
```
"msg": "=============== untagged roles z d c b a tagged tasks reverse ========"
"msg": "Role C tagged"
"msg": "=============== untagged roles z d c b a untagged tasks reverse ======"
"msg": "=============== tagged roles a b c d z tagged tasks =================="
"msg": "Role A tagged"
"msg": "Role B tagged"
"msg": "Role C tagged"
"msg": "Role C tagged"
"msg": "=============== tagged roles z d c b a tagged tasks reverse =========="
"msg": "Role C tagged"
"msg": "Role A tagged"
"msg": "Role B tagged"
"msg": "Role C tagged"
"msg": "=============== tagged roles a b c d z untagged tasks ================"
"msg": "Role A untagged"
"msg": "Role B untagged"
"msg": "Role C untagged"
"msg": "=============== tagged roles z d c b a untagged tasks reverse ========"
"msg": "Role A untagged"
"msg": "Role B untagged"
"msg": "Role C untagged"
```

`./test.sh --tags 'b,c'`
Running just two selected roles (and their dependencies) there were **NO** correct outputs.

***NOTE:*** **NONE** of the configurations produce the required result of running just roles **"A B C"**
```
    "msg": "=============== untagged roles z d c b a tagged tasks reverse ========"
    "msg": "Role B tagged"
    "msg": "Role C tagged"
    "msg": "=============== untagged roles z d c b a untagged tasks reverse ======"
    "msg": "=============== tagged roles a b c d z tagged tasks =================="
    "msg": "Role A tagged"
    "msg": "Role B tagged"
    "msg": "Role B tagged"
    "msg": "Role C tagged"
    "msg": "Role C tagged"
    "msg": "=============== tagged roles z d c b a tagged tasks reverse =========="
    "msg": "Role B tagged"
    "msg": "Role C tagged"
    "msg": "Role A tagged"
    "msg": "Role C tagged"
    "msg": "Role B tagged"
    "msg": "=============== tagged roles a b c d z untagged tasks ================"
    "msg": "Role A untagged"
    "msg": "Role B untagged"
    "msg": "Role B untagged"
    "msg": "Role C untagged"
    "msg": "=============== tagged roles z d c b a untagged tasks reverse ========"
    "msg": "Role A untagged"
    "msg": "Role B untagged"
    "msg": "Role C untagged"
    "msg": "Role B untagged"
```

Conclusion ... the *only* way to be able to handle the two scenarios with dependencies (run the whole playbook (all roles) or run just a subset of roles) is to ensure that the tags used for selection are **ONLY** in the role definition, and **NOT** on the tasks themselves.  Such as :
```
    - { role: a_untagged, tags: a }
```
Any tags on the tasks should only be for the tasks, **NOT** for any role selection.  Even so, this only works when selecting a single role/tag via **--tags 'c'** to run, and fails with multiples via **--tags 'b,c'**  as the last sample shows.

In the ***test.yml*** playbook file, that's the last two plays (role order doesn't matter).  All other variants do not produce the correct results.  It almost seems as if there's no reason to have *tags:* on the tasks themselves, at least if you want role/task selection to work with dependencies and no multiple-executions.

