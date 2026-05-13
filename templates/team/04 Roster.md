---
uid: {{UID}}
type: roster
project: "{{PROJECT_NAME}}"
last_reviewed: "{{CREATED_AT}}"
---

# Roster — {{PROJECT_NAME}}

Who is on this team, what they own, and how to reach them. Edited via PR; tag @{{TEAM_LEAD}} to review.

## Team

| Name | Role | GitHub | Timezone | Focus area |
|---|---|---|---|---|
| {{TEAM_LEAD_NAME}} | Team Lead | @{{TEAM_LEAD}} | {{TZ}} | |

## How to add someone

Add a row to the table above and open a PR. The CODEOWNERS rule requires @{{TEAM_LEAD}} approval before merge.

Include:
- **Name**: display name
- **Role**: what they are doing on this project (not their company title)
- **GitHub**: handle, used for mentions and CODEOWNERS
- **Timezone**: UTC offset or city (e.g. UTC-5 / New York)
- **Focus area**: what part of the project they own or are closest to

## Alumni

People who contributed and have since moved on. Keeping them here preserves attribution in old entries.

| Name | Role | Period |
|---|---|---|

---

_This file is owner-gated. The team lead is the merge approver._
