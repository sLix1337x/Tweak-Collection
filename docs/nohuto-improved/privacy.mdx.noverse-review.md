# privacy.mdx + privacy-identifiers.mdx — noverse cross-check

Cross-checked against nohuto's Noverse Windows Configuration (AGPL-3.0, research reference
only; all wording below is ours). Primary noverse sources deep-read:

- https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/
- https://noverse.dev/docs/win-config/privacy/disable-suggestions-tips-tricks/
- https://noverse.dev/docs/win-config/privacy/disable-activity-history/
- https://noverse.dev/docs/win-config/privacy/disable-wer/
- https://noverse.dev/docs/win-config/privacy/disable-application-compatibility/
- https://noverse.dev/docs/win-config/privacy/deny-app-access/
- https://noverse.dev/docs/win-config/privacy/disable-background-apps/
- https://noverse.dev/docs/win-config/privacy/disable-apps-for-websites/
- https://noverse.dev/docs/win-config/privacy/troubleshooter-preference/
- https://noverse.dev/docs/win-config/system/disable-services-drivers/
- https://noverse.dev/docs/win-config/system/disable-scheduled-tasks/
- Pseudocode: https://github.com/nohuto/decompiled-pseudocode/tree/main/11-23H2/DiagnosticDataSettings

## Claim-by-claim verification

### 1. Intro: everything is a Group Policy value under `HKLM\SOFTWARE\Policies`; policies survive feature updates; revert by deleting

- **Our claim:** all values in the category are policy values; they persist better than
  app-level toggles; deleting the value reverts.
- **noverse position:** AGREES (in practice) / NOT-COVERED (persistence sub-claim).
  His entire privacy category is built on `HKLM\Software\Policies\...` values (same policy-first
  approach), and he cross-links every entry to his ADMX-derived policy browser. He never
  comments on comparative persistence across feature updates.
- **Evidence:** policy tables at
  https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/ and
  https://noverse.dev/docs/win-config/privacy/disable-suggestions-tips-tricks/ . One nuance he
  documents that we miss: the telemetry level is also read from a **non-policy** path,
  `HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\DataCollection\AllowTelemetry`
  (DiagTrack local setting), plus per-user policy copies under
  `HKCU\Software\Policies\Microsoft\Windows\DataCollection` — same URL (23H2
  DiagnosticDataSettings pseudocode listing).

### 2. Framing: privacy/maintenance changes, not FPS or 1%-low optimizations

- **Our claim:** keep these separate from performance benchmarking.
- **noverse position:** AGREES. His privacy pages are purely about reducing data sent to
  Microsoft; no performance claims anywhere in the category. His service guidance is also
  explicitly conservative: he recommends disabling only the telemetry/diagnostics/location
  group, "as most other features won't start automatically anyway"
  (https://noverse.dev/docs/win-config/system/disable-services-drivers/).

### 3. `AllowTelemetry = 0` means Security level

- **Our claim:** policy value 0 = Security ("Diagnostic data off").
- **noverse position:** AGREES. He documents `AllowTelemetry` under both the policy key and
  the DiagTrack local-settings key with data 0/1/2/3; his pseudocode note adds that value **2
  is normalized to 1** at read time (Enhanced no longer exists), 3 = full diagnostic, and
  values >3 are not clamped — consistent with the Microsoft level table we cite.
- **Evidence:** https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/ ;
  pseudocode function list incl. `TelGetNumericPolicy` / `TelEvaluateActiveSettingAuthority`
  at https://github.com/nohuto/decompiled-pseudocode/tree/main/11-23H2/DiagnosticDataSettings .

### 4. Security (0) is only honored on Enterprise/Education/IoT; Home/Pro clamp to Basic/Required

- **Our claim:** the SKU clamp makes 0 equivalent to 1 on Home/Pro.
- **noverse position:** NOT-COVERED. He never states the SKU clamp in prose. His pseudocode
  material shows the *machinery* it would live in — `TelGetMaximumAllowedTelemetryLevel`
  reading a `MaxTelemetryAllowed` value from the DiagTrack local key — but his page does not
  say "0 behaves as 1 on Pro".
- **Evidence:** https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/ ;
  https://github.com/nohuto/decompiled-pseudocode/blob/main/11-23H2/DiagnosticDataSettings/TelGetMaximumAllowedTelemetryLevel.c .
- **Assessment:** our claim stays sourced to Microsoft's own Policy CSP text ("Using this
  setting on other devices is equivalent to setting the value of 1"), which wins here. No
  change needed; optionally cite the `MaxTelemetryAllowed` mechanism as the in-binary
  counterpart.

### 5. Required is the floor without an Enterprise SKU, and lower than the default

- **Our claim:** 1 is the effective minimum on Home/Pro and below what a default consumer
  install sends.
- **noverse position:** NOT-COVERED. No default-level discussion on his telemetry page.

### 6. `DoNotShowFeedbackNotifications = 1` (same DataCollection policy key)

- **Our claim:** suppresses feedback notifications.
- **noverse position:** AGREES. Identical key and value in his "Do not show feedback
  notifications" policy row.
- **Evidence:** https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/ .

### 7. "Telemetry completely off" on Windows 11 Pro via registry is impossible; pair the policy with the transport

- **Our claim:** registry level alone can't zero telemetry on Pro; disable the transport
  services for the real effect.
- **noverse position:** AGREES-WITH-NUANCE — he agrees and then goes further on two axes:
  1. He also disables DiagTrack (it sits in the always-recommended "main" service option),
     corroborating the policy-plus-transport model
     (https://noverse.dev/docs/win-config/system/disable-services-drivers/).
  2. He treats registry+services as still insufficient and recommends **endpoint-level
     blocking**: a Microsoft-connection hosts/DNS blocklist built from Microsoft's own
     "Windows 11 endpoints for non-Enterprise editions" documentation
     (https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/).
  He also covers channels our page never mentions as remaining transport: WER's watson
  endpoints (https://noverse.dev/docs/win-config/privacy/disable-wer/), CEIP/SQM
  (`HKLM\Software\Policies\Microsoft\SQMClient\Windows\CEIPEnable`), and OneSettings
  downloads (`DisableOneSettingsDownloads` under the DataCollection policy key,
  https://noverse.dev/docs/win-config/privacy/disable-onesettings-download/).
- **Assessment:** no conflict — his material strengthens and extends our point.

### 8. DiagTrack = Connected User Experiences and Telemetry, collects and uploads diagnostic data

- **Our claim:** service name and role; it is the transport for the policy level.
- **noverse position:** AGREES. His services table gives the same role description
  (event-driven collection and transmission of diagnostic/usage information) and puts
  DiagTrack in the main disable group.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/
  (Telemetry table).

### 9. dmwappushservice: WAP Push Message Routing Service, device-management routing "used by telemetry"

- **Our claim:** display name; device-management message routing; "used by telemetry".
- **noverse position:** AGREES-WITH-NUANCE. His description is the neutral Microsoft one —
  routes WAP push messages and synchronizes device-management sessions — with no telemetry
  mechanism. However he files the service under his **Telemetry** category and disables it in
  the main option, so he endorses removing it on privacy grounds without claiming a specific
  telemetry link.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/
  (Telemetry table).
- **Assessment:** noverse does not corroborate "used by telemetry" as a mechanism. Combined
  with the prior validation (no Microsoft source ties this service to the diagnostic-data
  pipeline), our wording should be softened to "ships with the telemetry group / needed for
  MDM" rather than asserting the link.

### 10. Cost of disabling them: Feedback Hub breaks, enterprise device management breaks, personal machine fine

- **Our claim:** Feedback Hub submission stops; MDM scenarios break; nothing else on a
  personal machine.
- **noverse position:** AGREES-WITH-NUANCE. No explicit cost discussion, but his
  dmwappushservice description (MDM session sync) matches the MDM-breakage half, and his
  overall stance — disable only the telemetry group, everything else only "for a specific
  reason" because it "may cause broken functionalities" — matches the "personal machine,
  minimal fallout" half. Feedback Hub is not mentioned.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ .

### 11. Tip: killing WSearch/SysMain/wuauserv/WaaSMedicSvc isn't worth it

- **Our claim:** those make the machine measurably worse or strip security updates.
- **noverse position:** AGREES. His explicit recommendation is to use only the main
  (telemetry/diagnostics/location) service option: "It is not necessary to disable more than
  this, as most other features won't start automatically anyway." Windows Search and similar
  are only offered as separately-justified sub-options.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ .

### 12. (identifiers) Intro: advertising ID, activity history, silent apps are not diagnostic telemetry; all Group Policy; revert by delete

- **Our claim:** three independent channels, policy-controlled.
- **noverse position:** AGREES. He handles the same three topics as policy-based items, but
  files advertising ID *inside* "Disable General Telemetry"
  (https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/), activity history
  standalone (https://noverse.dev/docs/win-config/privacy/disable-activity-history/), and
  consumer experiences under suggestions/tips
  (https://noverse.dev/docs/win-config/privacy/disable-suggestions-tips-tricks/).
  Categorization differs; mechanism agrees — none of them is governed by `AllowTelemetry`.

### 13. (identifiers) Advertising ID is a stable per-user identifier apps can read to correlate activity

- **Our claim:** mechanism description.
- **noverse position:** AGREES. He documents the identical policy — "Turn off the advertising
  ID", `HKLM\Software\Policies\Microsoft\Windows\AdvertisingInfo\DisabledByGroupPolicy` — with
  no contradicting mechanism text.
- **Evidence:** https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/ .

### 14. (identifiers) `DisabledByGroupPolicy = 1` turns the ID off and clears it; no functional downside

- **Our claim:** off + cleared; no downside.
- **noverse position:** AGREES on the policy and value; NOT-COVERED on "clears it" and the
  downside assessment (he has no prose on this policy at all).
- **Evidence:** https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/ .
- **Assessment:** keep the prior validation's nuance — policy path makes the ID unusable by
  apps; "reset/clear" wording is only documented for the Settings toggle.

### 15. (identifiers) `PublishUserActivities = 0` stops local collection; `UploadUserActivities = 0` stops MSA upload; setting only the second is a half-measure

- **Our claim:** publish = local store, upload = cloud sync; upload-only leaves the local DB
  growing.
- **noverse position:** AGREES, and adds a third sibling policy. His wording: publish allows
  or blocks *local* publishing; upload allows or blocks uploading to the cloud, and **deletion
  is not affected by the upload policy** — exactly our half-measure analysis. He additionally
  lists `EnableActivityFeed` (same `HKLM\Software\Policies\Microsoft\Windows\System` key) as
  the master publish-and-sync switch, and `HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer\DisableSearchHistory`
  as adjacent.
- **Evidence:** https://noverse.dev/docs/win-config/privacy/disable-activity-history/ .

### 16. (identifiers) Cost: "Pick up where I left off" and cross-device Timeline stop working

- **Our claim:** the trade-off is losing Timeline/cross-device resume.
- **noverse position:** CONTRADICTS — the feature is already dead. He quotes Microsoft:
  activity history with cross-device sync "is available in versions of Windows released prior
  to January 2024, and has been discontinued in new versions of Windows."
- **Evidence:** https://noverse.dev/docs/win-config/privacy/disable-activity-history/ .
- **Assessment:** noverse and the prior local validation (MS deprecated-features list, MSA
  upload ended 2021, Entra upload ended Jan 2024) agree. Our page should be fixed: on current
  Windows 11 there is no Timeline UX left to lose; the remaining, real effect of
  `PublishUserActivities = 0` is stopping the *local* activity store that feeds Start
  "Recommended" and Task View recents. Both sources outweigh our current text.

### 17a. (identifiers) `DisableWindowsConsumerFeatures = 1` stops promoted apps/games and Start suggestions

- **Our claim:** blocks silent app installs and Start "suggestions".
- **noverse position:** AGREES-WITH-NUANCE. He lists the identical policy under its Microsoft
  name "Turn off Microsoft consumer experiences"
  (https://noverse.dev/docs/win-config/privacy/disable-suggestions-tips-tricks/). What he adds
  is the layer that actually works per-user: his reverse-engineered table of
  `SubscribedContent-<id>Enabled` values from `ContentDeliveryManager.Utilities.dll`, including
  `SilentInstalledApps` (`202913`, `202914`) and `StartSuggestions` (`338381`, `338388`), and
  the note that `338389` is the only such value present by default. He does not mention the
  Enterprise/Education-only edition restriction from Microsoft's Policy CSP matrix — both
  sites are silent there; the restriction itself is documented by Microsoft, so the caveat
  from the prior validation stands regardless of noverse's silence.
- **Evidence:** https://noverse.dev/docs/win-config/privacy/disable-suggestions-tips-tricks/ .

### 17b. (identifiers) `DisableSoftLanding = 1` stops Start menu "suggestions"

- **Our claim:** DisableSoftLanding contributes to stopping Start suggestions.
- **noverse position:** CONTRADICTS. He files the identical value under Microsoft's policy
  name **"Do not show Windows tips"** — i.e., soft-landing Windows tips, not Start menu app
  suggestions — alongside the separate consumer-experiences policy.
- **Evidence:** https://noverse.dev/docs/win-config/privacy/disable-suggestions-tips-tricks/ .
- **Assessment:** noverse matches Microsoft's ADMX/CSP wording, which also marks the policy
  deprecated. Both sources outweigh ours; fix the description (see Improvements).

### 18. (identifiers) Apply on a fresh install before first Microsoft-account sign-in, when most silent installs happen

- **Our claim:** timing advice.
- **noverse position:** NOT-COVERED explicitly; indirectly consistent — his SubscribedContent
  table includes dedicated `OobeOffers` (`314566`/`314567`) and `MinuteZeroOffers`
  (`310094`/`310093`) categories, confirming that the content-delivery system has specific
  channels for exactly the setup/first-run window we describe.
- **Evidence:** https://noverse.dev/docs/win-config/privacy/disable-suggestions-tips-tricks/ .

### 19. (identifiers) Cost of the consumer-features tweak: "nothing you will miss"

- **Our claim:** editorial cost assessment.
- **noverse position:** NOT-COVERED (he gives no cost discussion for these policies).

## Improvements to adopt

Concrete, merge-ready additions/corrections in our own words:

1. **Fix the activity-history cost note (privacy-identifiers.mdx).** Replace the Timeline
   framing: cross-device activity sync was discontinued by Microsoft (uploads for new
   activities ended for consumer accounts years ago and the whole experience is gone from
   current Windows 11), so on a modern build there is no visible feature to lose. The tweak's
   real present-day effect is local: `PublishUserActivities = 0` stops the on-device activity
   store that feeds Start "Recommended" and Task View recents. Also add the third sibling
   policy `EnableActivityFeed = 0` in the same key as the master publish-and-sync switch.
   Sources: https://noverse.dev/docs/win-config/privacy/disable-activity-history/ .

2. **Fix the DisableSoftLanding description (privacy-identifiers.mdx).** Attribute it to what
   the policy actually is — "Do not show Windows tips" (soft-landing tips), and note Microsoft
   marks it deprecated. Start-suggestion blocking belongs to `DisableWindowsConsumerFeatures`
   and, per-user, to the ContentDeliveryManager values below. Source:
   https://noverse.dev/docs/win-config/privacy/disable-suggestions-tips-tricks/ .

3. **Add the per-user ContentDeliveryManager values as the Pro/Home-effective layer
   (privacy-identifiers.mdx).** Alongside the CloudContent policies, document
   `HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-<id>Enabled = 0`
   for the IDs reverse-engineered from `ContentDeliveryManager.Utilities.dll`: Start
   suggestions `338381`/`338388`, silently installed apps `202913`/`202914`, Windows tips
   `338389` (the only one present by default), Timeline content `353698`/`353699`, Settings
   "Recommendations & offers" `338393`/`353694`/`353696`, OOBE/first-run offers
   `314566`/`314567` and `310094`/`310093`. Source:
   https://noverse.dev/docs/win-config/privacy/disable-suggestions-tips-tricks/ .

4. **Widen the telemetry section's coverage (privacy.mdx).** Add, as optional extras under
   the same DataCollection policy key: `DisableOneSettingsDownloads = 1` (stops Windows
   pulling dynamic service configuration), `AllowDeviceNameInTelemetry = 0`,
   `LimitDiagnosticLogCollection = 1`, `LimitDumpCollection = 1` (only relevant at levels
   2/3), `DisableTelemetryOptInSettingsUx = 1`. Also worth one line: DiagTrack additionally
   reads a non-policy `AllowTelemetry` value under
   `HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\DataCollection`, and telemetry
   level 2 is normalized to 1 at read time (Enhanced is dead). Sources:
   https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/ and
   https://noverse.dev/docs/win-config/privacy/disable-onesettings-download/ .

5. **Name the adjacent telemetry pipelines we currently ignore (privacy.mdx).** One short
   subsection or tip covering: CEIP (`HKLM\Software\Policies\Microsoft\SQMClient\Windows\CEIPEnable = 0`
   plus the Customer Experience Improvement Program scheduled tasks — Consolidator, UsbCeip);
   Application Experience inventory/appraiser (`HKLM\Software\Policies\Microsoft\Windows\AppCompat\AITEnable = 0`,
   `DisableInventory = 1`, the Microsoft Compatibility Appraiser tasks, `InventorySvc`,
   `PcaSvc`); inking/typing (`HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\TextInput\AllowLinguisticDataCollection = 0`);
   online speech (`HKLM\Software\Policies\Microsoft\InputPersonalization\AllowInputPersonalization = 0`).
   Sources: https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/ ,
   https://noverse.dev/docs/win-config/privacy/disable-application-compatibility/ ,
   https://noverse.dev/docs/win-config/system/disable-scheduled-tasks/ ,
   https://noverse.dev/docs/win-config/system/disable-services-drivers/ .

6. **Extend the "where this stops" tip with the two remaining transport layers
   (privacy.mdx).** After the service pair, note that (a) Windows Error Reporting is a
   separate pipeline not governed by `AllowTelemetry` — own service `WerSvc`, the
   `QueueReporting` scheduled task, its own policy key
   `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting\Disabled`, and dedicated
   watson.* endpoints; and (b) the only further step past registry+services is blocking
   Microsoft's documented non-Enterprise connection endpoints at hosts/DNS level. Sources:
   https://noverse.dev/docs/win-config/privacy/disable-wer/ and
   https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/ .

7. **Soften the dmwappushservice line (privacy.mdx).** Drop or hedge "used by telemetry":
   keep the documented role (routes WAP push messages, synchronizes MDM sessions) and note it
   is grouped with telemetry-related services in community tooling, but no primary source ties
   it to the diagnostic-data pipeline. Source for the documented role:
   https://noverse.dev/docs/win-config/system/disable-services-drivers/ .

## Gaps noverse covers that we don't

Most relevant to these two pages' scope (telemetry, identifiers, unsolicited apps):

- Windows Error Reporting as a full pipeline: services (`WerSvc`, `wercplsupport`), the
  `QueueReporting` task, crash-dump levels, per-boot reliability timestamp policy, watson
  endpoints — https://noverse.dev/docs/win-config/privacy/disable-wer/
- OneSettings dynamic-configuration downloads (`DisableOneSettingsDownloads`,
  `EnableOneSettingsAuditing`) — https://noverse.dev/docs/win-config/privacy/disable-onesettings-download/
- Application Compatibility / inventory telemetry: CompatTelRunner tasks, `InventorySvc`,
  `PcaSvc`, AppCompat policies (some values 24H2-only) —
  https://noverse.dev/docs/win-config/privacy/disable-application-compatibility/
- CEIP scheduled tasks (Consolidator, UsbCeip, Autochk Proxy, DiskDiagnostic) —
  https://noverse.dev/docs/win-config/system/disable-scheduled-tasks/
- Per-capability app-access denies via CapabilityAccessManager ConsentStore (`Deny`) and the
  `AppPrivacy\LetAppsAccess*` policy family — https://noverse.dev/docs/win-config/privacy/deny-app-access/
- Background-app control (`AppPrivacy\LetAppsRunInBackground`) with its UWP notification/sync
  breakage caveat — https://noverse.dev/docs/win-config/privacy/disable-background-apps/
- Website language-list identifier opt-out
  (`HKCU\Control Panel\International\User Profile\HttpAcceptLanguageOptOut = 1`) —
  https://noverse.dev/docs/win-config/privacy/disable-apps-for-websites/
- Recommended-troubleshooter preference (`HKLM\SOFTWARE\Microsoft\WindowsMitigation\UserPreference`)
  and its diagnostic services — https://noverse.dev/docs/win-config/privacy/troubleshooter-preference/
- Clipboard history / cross-device clipboard policies —
  https://noverse.dev/docs/win-config/privacy/disable-clipboard/
- Copilot and Recall policies — https://noverse.dev/docs/win-config/privacy/disable-microsoft-copilot/
  and https://noverse.dev/docs/win-config/privacy/disable-recall/
- Microsoft-account SSO restriction (`Policies\System\NoConnectedUser`) —
  https://noverse.dev/docs/win-config/privacy/microsoft-accounts/
- Endpoint-level blocking (Microsoft non-Enterprise connection endpoints via hosts/DNS
  blocklist) as the layer beyond registry and services —
  https://noverse.dev/docs/win-config/privacy/disable-general-telemetry/

## Conflicts needing a decision

1. **DisableSoftLanding semantics — resolved against us.** Our page says it stops Start menu
   suggestions; noverse and Microsoft's policy name both say "Do not show Windows tips" (and
   Microsoft marks it deprecated, Enterprise/Education-only). Two independent sources outweigh
   ours: adopt the correction (Improvement 2).
2. **Activity-history "cost" — resolved against us.** Our page describes losing Timeline;
   Microsoft (quoted by noverse) says the synced activity-history experience was discontinued
   in Windows versions from January 2024 onward, and the prior local validation's
   deprecated-features citations agree. Adopt the reframe (Improvement 1).
3. **dmwappushservice "used by telemetry" — unresolved, leaning soften.** No primary source
   (Microsoft or otherwise) ties the service to the diagnostic-data pipeline; noverse groups
   it under Telemetry but describes only its WAP/MDM role. Recommend hedging the wording
   (Improvement 7) rather than asserting the link.
4. **CloudContent policies on Pro/Home — neither page addresses it.** Microsoft's Policy CSP
   edition matrix marks `AllowWindowsConsumerFeatures`/`DisableSoftLanding` as not applicable
   to Pro; noverse lists the policies without an edition note, we do the same. Not a
   noverse-vs-us conflict, but adding the edition caveat plus the per-user
   ContentDeliveryManager equivalents (Improvement 3) makes our page strictly more correct
   than both.
