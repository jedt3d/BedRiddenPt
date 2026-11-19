# Bedridden Patient Locator

Volunteers visit homes in Khlong San district, Bangkok, and register elderly people so it is known where they live and how much care they need.

## People

**Patient**:
An elderly person in the district who has been registered by a volunteer, whatever their care level.
_Avoid_: Bedridden patient (as the general term), resident, case

**Contact person**:
The one person to call about a patient: the household owner, a caregiver or relative, or the patient themselves ("self") when they can answer the phone. All of a patient's phone numbers belong to the contact person.
_Avoid_: Guardian, household owner, caregiver (as field names)

**Volunteer**:
The person who visits homes and registers patients. Each phone belongs to one volunteer.
_Avoid_: User, staff, recorder

## Care

**Care level**:
How much help a patient needs with daily living: **bedridden**, **homebound** or **social**. It sets the color of the patient's pin.
_Avoid_: Dependency, level, ADL group, severity

**ADL score**:
The 0–20 Barthel daily-living score that care level is derived from: bedridden 0–4, homebound 5–11, social 12–20.
_Avoid_: Care score, health score

**Care needs**:
The equipment or nursing a patient relies on: bedsore care, feeding tube, catheter, oxygen, air mattress, wheelchair. A patient can have any number of them, or none.
_Avoid_: Equipment, special needs, conditions

## Register

**Registration**:
The single record a volunteer keeps for a patient. Editing it replaces the old values; there is no history of visits.
_Avoid_: Visit, check-in, case file

**Status**:
Whether a patient still needs visiting: **active**, **in hospital**, **moved** or **deceased**.
_Avoid_: State, condition

**Inactive patient**:
A patient whose status is moved or deceased. Inactive patients are never deleted; they are hidden unless the volunteer chooses to show them.
_Avoid_: Deleted, archived, removed

**Sample pool**:
The 50 fictitious patients bundled with the prototype for testing. New registrations are prefilled from the part of the pool not yet registered.
_Avoid_: Bootstrap data, seed data, mock records

## Place

**Subdistrict**:
One of the four khwaeng of Khlong San district: Somdet Chao Phraya, Khlong San, Khlong Ton Sai and Bang Lamphu Lang.
_Avoid_: Village, tambon, area
