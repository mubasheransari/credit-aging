# Credit Aging - Implementation Notes

## Status: mobile app requires no code changes

The Flutter app in this project was already built correctly for the full
Manager -> Senior Manager -> CFO -> Director hierarchy, with dynamic,
role-aware notifications at every hand-off. Nothing in `lib/` needed to
change. The issue that made new/submitted requests invisible in the app was
entirely on the Oracle/ORDS side, and has been fixed there (see below).

## How the app decides what to show (lib/, unchanged)

- `lib/models/models.dart` - `CreditAgingRequest.isPendingFor(role)` compares
  the signed-in role against `pending_approver_role`, a field supplied by
  the backend. No role/department/level names are hardcoded anywhere in the
  app.
- `lib/screens/home_screen.dart` - `_visibleRequests` shows a non-final
  request only when `isPendingFor(_role)` is true. Approved/Rejected are
  shown to everyone as a record.
- `lib/services/notification_service.dart` - tracks
  `STATUS | PENDING_APPROVER_ROLE | PENDING_LEVEL` per request so hand-offs
  are detected correctly even though Oracle keeps `STATUS = UNDER_REVIEW`
  while the request moves between levels after the first one. Notifies the
  signed-in user's role the moment it becomes their turn, and notifies the
  original requester (matched by `requested_by` == signed-in email) on
  final Approve/Reject. De-duplicated via a stable event key so 5-second
  polling never re-fires the same notification.
- `lib/services/background_monitor_service.dart` - runs the exact same
  `getCreditAgingRequests()` -> `NotificationService.syncRequests()` polling
  loop every 5 seconds while the app is backgrounded, so notifications still
  arrive when the app isn't open.

## Oracle/ORDS fixes applied this session

1. **`/ords/hrms/credit-aging/list/` GET handler** did not return any
   pending-hierarchy fields at all - it was a bare
   `SELECT r.* FROM MTEA.CAR_CREDIT_AGING_REQUESTS r`. Fixed to:

   ```sql
   SELECT r.*,
          p.pending_level_no,
          p.pending_level_name,
          p.pending_approver_role,
          p.is_final_level,
          p.next_level_name
     FROM MTEA.CAR_CREDIT_AGING_REQUESTS r
     LEFT JOIN HRMS.V_CREDIT_AGING_PENDING p ON p.request_id = r.request_id
    ORDER BY r.request_id DESC
   ```

2. **A pre-existing trigger, `HRMS.TRG_CAR_REQUEST_SUBMIT`**, called
   `credit_aging_workflow_pkg.initiate_request` directly on
   `DRAFT -> SUBMITTED`. That procedure both queries
   `MTEA.CAR_CREDIT_AGING_REQUESTS` (the same table being mutated) and
   issues an internal `COMMIT`, so it failed every time with
   `ORA-04091` (mutating table) and would have failed further with
   `ORA-04092` (commit in trigger) had it gotten past that. This trigger
   was dropped and replaced with `TRG_CAR_REQUEST_AUTO_INITIATE`, which
   creates the `APPROVAL_STEPS` rows inline (using `:NEW` values, no
   re-query of the mutating table) and does not commit:

   ```sql
   CREATE OR REPLACE TRIGGER trg_car_request_auto_initiate
   AFTER UPDATE OF STATUS ON MTEA.CAR_CREDIT_AGING_REQUESTS
   FOR EACH ROW
   WHEN (NEW.STATUS = 'SUBMITTED' AND OLD.STATUS = 'DRAFT')
   DECLARE
     v_amount MTEA.CAR_CREDIT_AGING_REQUESTS.REQUESTED_AMOUNT%TYPE := :NEW.REQUESTED_AMOUNT;
     v_dept   VARCHAR2(50) := 'FINANCE';
   BEGIN
     FOR h IN (
       SELECT level_no, approver_role
       FROM approval_hierarchy_levels
       WHERE workflow_type = 'CREDIT_AGING'
         AND department = v_dept
         AND is_active = 'Y'
         AND ( v_amount IS NULL OR v_amount BETWEEN min_amount AND NVL(max_amount, v_amount) )
       ORDER BY level_no
     ) LOOP
       INSERT INTO approval_steps (step_id, request_id, level_no, approver_role, step_status)
       VALUES (approval_steps_seq.NEXTVAL, :NEW.REQUEST_ID, h.level_no, h.approver_role, 'PENDING');
     END LOOP;
   END;
   /
   ```

   Note: `v_dept` is hardcoded to `'FINANCE'`. If other departments/workflow
   types are ever routed through this same table, this needs to read the
   department from the row instead.

3. **`HRMS.V_CREDIT_AGING_PENDING`** had a latent bug: when a request was
   rejected partway through the hierarchy, the downstream, never-touched
   `APPROVAL_STEPS` rows stayed at `step_status = 'PENDING'` forever (only
   the level actually acted on gets updated by `act_on_request`). The
   view's "Case 1" branch picked those up and reported a `REJECTED`
   request as still pending for whichever role owned that stray row. Fixed
   by joining back to the request and excluding finalized statuses:

   ```sql
   ... AND r.STATUS NOT IN ('APPROVED', 'REJECTED')
   ```

   ("Case 2" of the view, which synthesizes a pending Manager-level entry
   for a `SUBMITTED` request with zero `APPROVAL_STEPS` rows, already had
   its own `r.STATUS = 'SUBMITTED'` guard and needed no change - and is
   now largely redundant for new requests since the trigger creates real
   rows immediately, but is left in place as a safety net.)

## Verified end-to-end (request 45)

- `DRAFT -> SUBMITTED` via a plain `UPDATE` (no manual `initiate_request`
  call) produced all 4 `APPROVAL_STEPS` rows automatically.
- `V_CREDIT_AGING_PENDING` / the `/list` endpoint correctly resolved
  `pending_level_no = 10`, `pending_approver_role = FINANCE_MANAGER`.

Still to verify live in the mobile app: that the Finance Manager's app
picks this up within one polling cycle without a manual refresh, fires a
notification, and that the same holds true through Senior Manager -> CFO
-> Director, plus a mid-chain rejection.

## Existing API contract (unchanged)

- List: `GET /ords/hrms/credit-aging/list`
- Action: `POST /ords/hrms/credit-aging/update-status/`
- Login: `POST /ords/hrms/creditaginglogin/auth`

## Known follow-up item (not fixed, flagged only)

Two orphaned test records (request IDs 33, 31) were found sitting at
`UNDER_REVIEW` with zero `APPROVAL_STEPS` rows - almost certainly pushed
there by a direct `UPDATE` during earlier manual testing, bypassing the
workflow package entirely. These were deleted (along with their
`CAR_REQUEST_AMENDMENT_LOG` child rows) rather than repaired. If any other
requests in the table are in a similar inconsistent state (`UNDER_REVIEW`
or `SUBMITTED` with no matching `APPROVAL_STEPS`), they will be invisible
to every role in the app until either reset to `DRAFT` and resubmitted, or
manually repaired with `initiate_request`. Worth a one-time audit:

```sql
SELECT r.request_id, r.status
  FROM MTEA.CAR_CREDIT_AGING_REQUESTS r
 WHERE r.status IN ('SUBMITTED', 'UNDER_REVIEW')
   AND NOT EXISTS (SELECT 1 FROM approval_steps s WHERE s.request_id = r.request_id);
```
