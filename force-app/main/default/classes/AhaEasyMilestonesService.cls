public with sharing class AhaEasyMilestonesService {
    private static final String ENTRY_CONTEXT = 'ENTRY';
    private static final String EXIT_CONTEXT = 'EXIT';
    private static final String UPDATE_CONTEXT_PROCESS_EXIT = 'PROCESS_EXIT';
    private static final String UPDATE_CONTEXT_MILESTONE_COMPLETE = 'MILESTONE_COMPLETE';

    @TestVisible private static AHA_EasyMilestones_Process__mdt testProcessOverride;
    @TestVisible private static List<AHA_EasyMilestones_Process_Milestone__mdt> testMilestoneOverrides;
    @TestVisible private static List<AHA_EasyMilestones_Milestone_Validation__mdt> testValidationOverrides;
    @TestVisible private static List<AHA_EasyMilestones_Exit_Field_Update__mdt> testExitUpdateOverrides;
    @TestVisible private static List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt> testCriteriaOverrides;
    @TestVisible private static Set<String> testReferencedFieldOverrides;

    @TestVisible private static Map<String, String> testMilestoneToProcessDeveloperName;
    @TestVisible private static Map<String, String> testValidationToMilestoneDeveloperName;
    @TestVisible private static Map<String, String> testExitUpdateToMilestoneDeveloperName;
    @TestVisible private static Map<String, String> testCriteriaToProcessDeveloperName;

    private class ProcessMatchResult {
        public AHA_EasyMilestones_Process__mdt processConfig;
        public Boolean entryMatched = false;
        public Boolean exitMatched = false;
    }

    public static AhaEasyMilestonesDtos.PanelDto buildPanel(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('recordId is required.');
        }

        SObject recordSObject = loadRecord(recordId);
        String objectApiName = recordId.getSObjectType().getDescribe().getName();

        List<AHA_EasyMilestones_Process__mdt> processConfigs = getActiveProcessesForObject(objectApiName);

        AhaEasyMilestonesDtos.PanelDto panel = new AhaEasyMilestonesDtos.PanelDto();
        panel.recordId = recordId;

        if (processConfigs.isEmpty()) {
            panel.message = 'No active SLA Process configuration found for this record.';
            return panel;
        }

        ProcessMatchResult matchResult = findApplicableProcess(recordSObject, processConfigs);

        if (matchResult == null || matchResult.processConfig == null) {
            panel.message = 'There are no current active SLA\'s against this record.';
            return panel;
        }

        AHA_EasyMilestones_Process__mdt processConfig = matchResult.processConfig;
        panel.processDeveloperName = processConfig.DeveloperName;
        panel.processLabel = processConfig.MasterLabel;

        if (matchResult.exitMatched) {
            panel.message = 'The record meets SLA exit criteria.';
            return panel;
        }

        List<AHA_EasyMilestones_Process_Milestone__mdt> milestoneConfigs = getMilestones(processConfig.DeveloperName);

        for (AHA_EasyMilestones_Process_Milestone__mdt milestoneConfig : milestoneConfigs) {
            panel.milestones.add(buildMilestone(recordSObject, processConfig, milestoneConfig));
        }

        return panel;
    }

    public static AhaEasyMilestonesDtos.ActionResultDto markComplete(Id recordId, String milestoneDeveloperName) {
        if (recordId == null) {
            throw new AuraHandledException('recordId is required.');
        }
        if (String.isBlank(milestoneDeveloperName)) {
            throw new AuraHandledException('milestoneDeveloperName is required.');
        }

        SObject recordSObject = loadRecord(recordId);
        String objectApiName = recordId.getSObjectType().getDescribe().getName();

        List<AHA_EasyMilestones_Process__mdt> processConfigs = getActiveProcessesForObject(objectApiName);
        if (processConfigs.isEmpty()) {
            throw new AuraHandledException('No active SLA Process configuration found.');
        }

        ProcessMatchResult matchResult = findApplicableProcess(recordSObject, processConfigs);
        if (matchResult == null || matchResult.processConfig == null || matchResult.exitMatched) {
            throw new AuraHandledException('No active SLA Process configuration found.');
        }

        AHA_EasyMilestones_Process__mdt processConfig = matchResult.processConfig;

        AHA_EasyMilestones_Process_Milestone__mdt milestoneConfig = getMilestoneByDeveloperName(milestoneDeveloperName);

        if (milestoneConfig == null) {
            throw new AuraHandledException('Milestone configuration not found.');
        }

        if (!milestoneConfig.Manual_Completion_Enabled__c) {
            throw new AuraHandledException('Manual completion is not enabled for this milestone.');
        }

        List<AHA_EasyMilestones_Milestone_Validation__mdt> validations = getValidations(milestoneConfig.DeveloperName);

        for (AHA_EasyMilestones_Milestone_Validation__mdt validation : validations) {
            String validationError = validateRule(
                recordSObject,
                validation.Field_API_Name__c,
                validation.Validation_Rule_JSON__c
            );

            if (validationError != null) {
                AhaEasyMilestonesDtos.ActionResultDto failed = new AhaEasyMilestonesDtos.ActionResultDto();
                failed.success = false;
                failed.message = String.isBlank(validation.Error_Message__c)
                    ? validationError
                    : validation.Error_Message__c;
                failed.panel = buildPanel(recordId);
                return failed;
            }
        }

        List<AHA_EasyMilestones_Exit_Field_Update__mdt> updates = getExitUpdates(
            UPDATE_CONTEXT_MILESTONE_COMPLETE,
            milestoneConfig.DeveloperName
        );

        applyFieldUpdates(recordSObject, updates);
        update recordSObject;

        AhaEasyMilestonesDtos.ActionResultDto result = new AhaEasyMilestonesDtos.ActionResultDto();
        result.success = true;
        result.message = 'Milestone marked complete.';
        result.panel = buildPanel(recordId);
        return result;
    }

    private static List<AHA_EasyMilestones_Process__mdt> getActiveProcessesForObject(String objectApiName) {
        if (Test.isRunningTest() && testProcessOverride != null) {
            if (testProcessOverride.Active__c == true &&
                testProcessOverride.Target_Object_API_Name__c == objectApiName) {
                return new List<AHA_EasyMilestones_Process__mdt>{ testProcessOverride };
            }
            return new List<AHA_EasyMilestones_Process__mdt>();
        }

        return [
            SELECT DeveloperName,
                   MasterLabel,
                   Target_Object_API_Name__c,
                   Business_Hours_Id__c,
                   Description__c,
                   Active__c
            FROM AHA_EasyMilestones_Process__mdt
            WHERE Active__c = true
              AND Target_Object_API_Name__c = :objectApiName
            ORDER BY MasterLabel ASC, DeveloperName ASC
        ];
    }

    private static ProcessMatchResult findApplicableProcess(
        SObject recordSObject,
        List<AHA_EasyMilestones_Process__mdt> processConfigs
    ) {
        ProcessMatchResult firstExitedMatch;

        for (AHA_EasyMilestones_Process__mdt processConfig : processConfigs) {
            Boolean entryMatched = evaluateProcessContext(
                recordSObject,
                processConfig.DeveloperName,
                ENTRY_CONTEXT
            );

            if (!entryMatched) {
                continue;
            }

            Boolean exitMatched = evaluateProcessContext(
                recordSObject,
                processConfig.DeveloperName,
                EXIT_CONTEXT
            );

            ProcessMatchResult current = new ProcessMatchResult();
            current.processConfig = processConfig;
            current.entryMatched = true;
            current.exitMatched = exitMatched;

            if (!exitMatched) {
                return current;
            }

            if (firstExitedMatch == null) {
                firstExitedMatch = current;
            }
        }

        return firstExitedMatch;
    }

    private static String getOverrideProcessDeveloperNameForCriteria(AHA_EasyMilestones_Entry_Exit_Criteria__mdt row) {
        if (row == null) {
            return null;
        }
        if (Test.isRunningTest() && testCriteriaToProcessDeveloperName != null) {
            return testCriteriaToProcessDeveloperName.get(row.DeveloperName);
        }
        return null;
    }

    private static String getOverrideProcessDeveloperNameForMilestone(AHA_EasyMilestones_Process_Milestone__mdt row) {
        if (row == null) {
            return null;
        }
        if (Test.isRunningTest() && testMilestoneToProcessDeveloperName != null) {
            return testMilestoneToProcessDeveloperName.get(row.DeveloperName);
        }
        return null;
    }

    private static String getOverrideMilestoneDeveloperNameForValidation(AHA_EasyMilestones_Milestone_Validation__mdt row) {
        if (row == null) {
            return null;
        }
        if (Test.isRunningTest() && testValidationToMilestoneDeveloperName != null) {
            return testValidationToMilestoneDeveloperName.get(row.DeveloperName);
        }
        return null;
    }

    private static String getOverrideMilestoneDeveloperNameForExitUpdate(AHA_EasyMilestones_Exit_Field_Update__mdt row) {
        if (row == null) {
            return null;
        }
        if (Test.isRunningTest() && testExitUpdateToMilestoneDeveloperName != null) {
            return testExitUpdateToMilestoneDeveloperName.get(row.DeveloperName);
        }
        return null;
    }

    private static List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt> getCriteria(String processDeveloperName, String context) {
        if (Test.isRunningTest() && testCriteriaOverrides != null) {
            List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt> results = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>();

            for (AHA_EasyMilestones_Entry_Exit_Criteria__mdt row : testCriteriaOverrides) {
                if (row.Active__c == true &&
                    getOverrideProcessDeveloperNameForCriteria(row) == processDeveloperName &&
                    row.Criteria_Context__c == context) {
                    results.add(row);
                }
            }

            return results;
        }

        return [
            SELECT DeveloperName,
                   MasterLabel,
                   Description__c,
                   Process__c,
                   Process__r.DeveloperName,
                   Criteria_Context__c,
                   Criteria_JSON__c,
                   Sequence__c,
                   Active__c
            FROM AHA_EasyMilestones_Entry_Exit_Criteria__mdt
            WHERE Active__c = true
              AND Process__r.DeveloperName = :processDeveloperName
              AND Criteria_Context__c = :context
            ORDER BY Sequence__c ASC, DeveloperName ASC
        ];
    }

    private static List<AHA_EasyMilestones_Process_Milestone__mdt> getMilestones(String processDeveloperName) {
        if (Test.isRunningTest() && testMilestoneOverrides != null) {
            List<AHA_EasyMilestones_Process_Milestone__mdt> results = new List<AHA_EasyMilestones_Process_Milestone__mdt>();

            for (AHA_EasyMilestones_Process_Milestone__mdt row : testMilestoneOverrides) {
                if (row.Active__c == true &&
                    getOverrideProcessDeveloperNameForMilestone(row) == processDeveloperName) {
                    results.add(row);
                }
            }

            return results;
        }

        return [
            SELECT DeveloperName,
                   MasterLabel,
                   Description__c,
                   Process__c,
                   Process__r.DeveloperName,
                   Time_Trigger_Minutes__c,
                   Start_Field_API_Name__c,
                   Reset_Enabled__c,
                   Reset_Field_API_Name__c,
                   Extension_Enabled__c,
                   Extension_Field_API_Name__c,
                   Manual_Completion_Enabled__c,
                   Business_Hours_Id_Override__c,
                   Sequence__c,
                   Active__c
            FROM AHA_EasyMilestones_Process_Milestone__mdt
            WHERE Active__c = true
              AND Process__r.DeveloperName = :processDeveloperName
            ORDER BY Sequence__c ASC, DeveloperName ASC
        ];
    }

    private static AHA_EasyMilestones_Process_Milestone__mdt getMilestoneByDeveloperName(String milestoneDeveloperName) {
        if (Test.isRunningTest() && testMilestoneOverrides != null) {
            for (AHA_EasyMilestones_Process_Milestone__mdt row : testMilestoneOverrides) {
                if (row.Active__c == true && row.DeveloperName == milestoneDeveloperName) {
                    return row;
                }
            }
            return null;
        }

        List<AHA_EasyMilestones_Process_Milestone__mdt> milestoneList = [
            SELECT DeveloperName,
                   MasterLabel,
                   Description__c,
                   Process__c,
                   Process__r.DeveloperName,
                   Time_Trigger_Minutes__c,
                   Start_Field_API_Name__c,
                   Reset_Enabled__c,
                   Reset_Field_API_Name__c,
                   Extension_Enabled__c,
                   Extension_Field_API_Name__c,
                   Manual_Completion_Enabled__c,
                   Business_Hours_Id_Override__c,
                   Sequence__c,
                   Active__c
            FROM AHA_EasyMilestones_Process_Milestone__mdt
            WHERE DeveloperName = :milestoneDeveloperName
              AND Active__c = true
            LIMIT 1
        ];

        return milestoneList.isEmpty() ? null : milestoneList[0];
    }

    private static List<AHA_EasyMilestones_Milestone_Validation__mdt> getValidations(String milestoneDeveloperName) {
        if (Test.isRunningTest() && testValidationOverrides != null) {
            List<AHA_EasyMilestones_Milestone_Validation__mdt> results = new List<AHA_EasyMilestones_Milestone_Validation__mdt>();

            for (AHA_EasyMilestones_Milestone_Validation__mdt row : testValidationOverrides) {
                if (row.Active__c == true &&
                    getOverrideMilestoneDeveloperNameForValidation(row) == milestoneDeveloperName) {
                    results.add(row);
                }
            }

            return results;
        }

        return [
            SELECT DeveloperName,
                   MasterLabel,
                   Description__c,
                   Process_Milestone__c,
                   Process_Milestone__r.DeveloperName,
                   Field_API_Name__c,
                   Validation_Rule_JSON__c,
                   Error_Message__c,
                   Sequence__c,
                   Active__c
            FROM AHA_EasyMilestones_Milestone_Validation__mdt
            WHERE Active__c = true
              AND Process_Milestone__r.DeveloperName = :milestoneDeveloperName
            ORDER BY Sequence__c ASC, DeveloperName ASC
        ];
    }

    private static List<AHA_EasyMilestones_Exit_Field_Update__mdt> getExitUpdates(String context, String milestoneDeveloperName) {
        if (Test.isRunningTest() && testExitUpdateOverrides != null) {
            List<AHA_EasyMilestones_Exit_Field_Update__mdt> results = new List<AHA_EasyMilestones_Exit_Field_Update__mdt>();

            for (AHA_EasyMilestones_Exit_Field_Update__mdt row : testExitUpdateOverrides) {
                if (row.Active__c == true &&
                    row.Update_Context__c == context &&
                    getOverrideMilestoneDeveloperNameForExitUpdate(row) == milestoneDeveloperName) {
                    results.add(row);
                }
            }

            return results;
        }

        return [
            SELECT DeveloperName,
                   MasterLabel,
                   Description__c,
                   Process__c,
                   Process_Milestone__c,
                   Process_Milestone__r.DeveloperName,
                   Update_Context__c,
                   Field_API_Name__c,
                   Update_Type__c,
                   Update_Value__c,
                   Sequence__c,
                   Active__c
            FROM AHA_EasyMilestones_Exit_Field_Update__mdt
            WHERE Active__c = true
              AND Update_Context__c = :context
              AND Process_Milestone__r.DeveloperName = :milestoneDeveloperName
            ORDER BY Sequence__c ASC, DeveloperName ASC
        ];
    }

    private static Boolean evaluateProcessContext(SObject recordSObject, String processDeveloperName, String context) {
        List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt> rules = getCriteria(processDeveloperName, context);

        if (rules.isEmpty()) {
            return context == ENTRY_CONTEXT;
        }

        for (AHA_EasyMilestones_Entry_Exit_Criteria__mdt rule : rules) {
            if (evaluateCriteriaJson(recordSObject, rule.Criteria_JSON__c)) {
                return true;
            }
        }

        return false;
    }

    private static AhaEasyMilestonesDtos.MilestoneDto buildMilestone(
        SObject recordSObject,
        AHA_EasyMilestones_Process__mdt processConfig,
        AHA_EasyMilestones_Process_Milestone__mdt milestoneConfig
    ) {
        AhaEasyMilestonesDtos.MilestoneDto dto = new AhaEasyMilestonesDtos.MilestoneDto();

        dto.developerName = milestoneConfig.DeveloperName;
        dto.label = milestoneConfig.MasterLabel;
        dto.description = milestoneConfig.Description__c;
        dto.sequence = milestoneConfig.Sequence__c == null ? null : Integer.valueOf(milestoneConfig.Sequence__c);
        dto.manualCompletionEnabled = milestoneConfig.Manual_Completion_Enabled__c;

        Datetime startDateTime = getDatetimeValue(recordSObject, milestoneConfig.Start_Field_API_Name__c);
        if (startDateTime == null && hasField(recordSObject, 'CreatedDate')) {
            startDateTime = (Datetime) recordSObject.get('CreatedDate');
        }

        if (milestoneConfig.Reset_Enabled__c && !String.isBlank(milestoneConfig.Reset_Field_API_Name__c)) {
            Datetime resetDateTime = getDatetimeValue(recordSObject, milestoneConfig.Reset_Field_API_Name__c);
            if (resetDateTime != null && (startDateTime == null || resetDateTime.getTime() > startDateTime.getTime())) {
                startDateTime = resetDateTime;
            }
        }

        dto.startDateTime = startDateTime;

        Integer baseMinutes = milestoneConfig.Time_Trigger_Minutes__c == null
            ? 0
            : Integer.valueOf(milestoneConfig.Time_Trigger_Minutes__c);

        Integer extensionMinutes = getExtensionMinutes(
            recordSObject,
            milestoneConfig.Extension_Enabled__c,
            milestoneConfig.Extension_Field_API_Name__c
        );

        Integer totalMinutes = baseMinutes + extensionMinutes;

        String businessHoursId = !String.isBlank(milestoneConfig.Business_Hours_Id_Override__c)
            ? milestoneConfig.Business_Hours_Id_Override__c
            : processConfig.Business_Hours_Id__c;

        dto.usesBusinessHours = !String.isBlank(businessHoursId);

        if (startDateTime != null) {
            dto.targetDateTime = calculateTarget(startDateTime, totalMinutes, businessHoursId);
        }

        dto.completed = isMilestoneCompleted(recordSObject, milestoneConfig.DeveloperName);

        if (dto.completed) {
            dto.status = 'Completed';
            dto.overdue = false;
            dto.businessTimeRunning = false;
            dto.remainingMilliseconds = 0;
            dto.displayText = 'Completed';
            return dto;
        }

        if (dto.targetDateTime == null) {
            dto.status = 'Pending';
            dto.overdue = false;
            dto.businessTimeRunning = false;
            dto.remainingMilliseconds = null;
            dto.displayText = 'Awaiting start';
            return dto;
        }

        Long remainingMs = calculateRemainingMilliseconds(dto.targetDateTime, businessHoursId);
        dto.remainingMilliseconds = remainingMs;
        dto.overdue = remainingMs < 0;
        dto.status = dto.overdue ? 'Overdue' : 'Active';
        dto.businessTimeRunning = isBusinessTimeRunning(businessHoursId);
        dto.displayText = formatDuration(remainingMs);

        return dto;
    }

    private static Boolean isMilestoneCompleted(SObject recordSObject, String milestoneDeveloperName) {
        List<AHA_EasyMilestones_Exit_Field_Update__mdt> completionUpdates = getExitUpdates(
            UPDATE_CONTEXT_MILESTONE_COMPLETE,
            milestoneDeveloperName
        );

        if (completionUpdates.isEmpty()) {
            return false;
        }

        for (AHA_EasyMilestones_Exit_Field_Update__mdt updateConfig : completionUpdates) {
            if (String.isBlank(updateConfig.Field_API_Name__c) || !hasField(recordSObject, updateConfig.Field_API_Name__c)) {
                continue;
            }

            Object actualValue = recordSObject.get(updateConfig.Field_API_Name__c);
            String updateType = String.valueOf(updateConfig.Update_Type__c).toUpperCase();

            if (updateType == 'TRUE' && !(actualValue instanceof Boolean && (Boolean) actualValue)) {
                return false;
            }
            if (updateType == 'FALSE' && !(actualValue instanceof Boolean && !((Boolean) actualValue))) {
                return false;
            }
            if (updateType == 'NOW' && actualValue == null) {
                return false;
            }
            if (updateType == 'STATIC') {
                Object expected = coerceValueForField(recordSObject, updateConfig.Field_API_Name__c, updateConfig.Update_Value__c);
                if (stringify(actualValue) != stringify(expected)) {
                    return false;
                }
            }
        }

        return true;
    }

    private static void applyFieldUpdates(SObject recordSObject, List<AHA_EasyMilestones_Exit_Field_Update__mdt> updates) {
        for (AHA_EasyMilestones_Exit_Field_Update__mdt config : updates) {
            if (String.isBlank(config.Field_API_Name__c) || !hasField(recordSObject, config.Field_API_Name__c)) {
                continue;
            }

            String updateType = String.valueOf(config.Update_Type__c).toUpperCase();

            if (updateType == 'NOW') {
                recordSObject.put(config.Field_API_Name__c, Datetime.now());
            } else if (updateType == 'TRUE') {
                recordSObject.put(config.Field_API_Name__c, true);
            } else if (updateType == 'FALSE') {
                recordSObject.put(config.Field_API_Name__c, false);
            } else if (updateType == 'NULL') {
                recordSObject.put(config.Field_API_Name__c, null);
            } else if (updateType == 'COPY_FIELD') {
                recordSObject.put(config.Field_API_Name__c, getFieldValue(recordSObject, config.Update_Value__c));
            } else {
                recordSObject.put(
                    config.Field_API_Name__c,
                    coerceValueForField(recordSObject, config.Field_API_Name__c, config.Update_Value__c)
                );
            }
        }
    }

    private static Integer getExtensionMinutes(
        SObject recordSObject,
        Boolean extensionEnabled,
        String extensionFieldApiName
    ) {
        if (extensionEnabled != true || String.isBlank(extensionFieldApiName) || !hasField(recordSObject, extensionFieldApiName)) {
            return 0;
        }

        Object value = recordSObject.get(extensionFieldApiName);
        if (value == null) {
            return 0;
        }

        Decimal extensionDays;
        try {
            extensionDays = Decimal.valueOf(String.valueOf(value));
        } catch (Exception ex) {
            return 0;
        }

        if (extensionDays <= 0) {
            return 0;
        }

        Decimal minutesPerBusinessDay = 480;
        return (extensionDays * minutesPerBusinessDay).intValue();
    }

    private static Datetime calculateTarget(Datetime startDateTime, Integer totalMinutes, String businessHoursId) {
        Long durationMillis = ((Long) totalMinutes) * 60L * 1000L;

        if (!String.isBlank(businessHoursId)) {
            try {
                return BusinessHours.add(businessHoursId, startDateTime, durationMillis);
            } catch (Exception ex) {
                // fallback below
            }
        }

        return startDateTime.addMinutes(totalMinutes);
    }

    private static Long calculateRemainingMilliseconds(Datetime targetDateTime, String businessHoursId) {
        if (targetDateTime == null) {
            return null;
        }

        Datetime nowValue = Datetime.now();

        if (!String.isBlank(businessHoursId)) {
            try {
                return BusinessHours.diff(businessHoursId, nowValue, targetDateTime);
            } catch (Exception ex) {
                // fallback below
            }
        }

        return targetDateTime.getTime() - nowValue.getTime();
    }

    private static Boolean isBusinessTimeRunning(String businessHoursId) {
        if (String.isBlank(businessHoursId)) {
            return true;
        }

        try {
            return BusinessHours.isWithin(businessHoursId, Datetime.now());
        } catch (Exception ex) {
            return true;
        }
    }

    private static String validateRule(SObject recordSObject, String fieldApiName, String validationJson) {
        if (String.isBlank(validationJson)) {
            return null;
        }

        Map<String, Object> rule = (Map<String, Object>) JSON.deserializeUntyped(validationJson);
        String typeName = String.valueOf(rule.get('type')).toUpperCase();
        Object actualValue = getFieldValue(recordSObject, fieldApiName);

        if (typeName == 'REQUIRED' && isBlankValue(actualValue)) {
            return fieldApiName + ' is required.';
        }
        if (typeName == 'EQUALS' && stringify(actualValue) != stringify(rule.get('value'))) {
            return fieldApiName + ' must equal ' + stringify(rule.get('value')) + '.';
        }
        if (typeName == 'NOT_EQUALS' && stringify(actualValue) == stringify(rule.get('value'))) {
            return fieldApiName + ' must not equal ' + stringify(rule.get('value')) + '.';
        }
        if (typeName == 'TRUE' && !(actualValue instanceof Boolean && (Boolean) actualValue)) {
            return fieldApiName + ' must be checked.';
        }
        if (typeName == 'FALSE' && (actualValue instanceof Boolean && !((Boolean) actualValue))) {
            return fieldApiName + ' must be unchecked.';
        }
        if (typeName == 'GREATER_THAN' && compareDecimal(actualValue, rule.get('value')) <= 0) {
            return fieldApiName + ' must be greater than ' + stringify(rule.get('value')) + '.';
        }
        if (typeName == 'LESS_THAN' && compareDecimal(actualValue, rule.get('value')) >= 0) {
            return fieldApiName + ' must be less than ' + stringify(rule.get('value')) + '.';
        }

        return null;
    }

    private static Boolean evaluateCriteriaJson(SObject recordSObject, String criteriaJson) {
        if (String.isBlank(criteriaJson)) {
            return true;
        }

        Object parsed = JSON.deserializeUntyped(criteriaJson);
        return evaluateCriteriaNode(recordSObject, parsed);
    }

    private static Boolean evaluateCriteriaNode(SObject recordSObject, Object node) {
        if (node == null) {
            return true;
        }

        if (!(node instanceof Map<String, Object>)) {
            return true;
        }

        Map<String, Object> mapRule = (Map<String, Object>) node;

        if (mapRule.containsKey('conditions')) {
            String logic = String.valueOf(mapRule.get('logic')).toUpperCase();
            List<Object> conditions = (List<Object>) mapRule.get('conditions');
            return evaluateConditionGroup(recordSObject, logic, conditions);
        }

        if (mapRule.containsKey('and')) {
            return evaluateConditionGroup(recordSObject, 'AND', (List<Object>) mapRule.get('and'));
        }

        if (mapRule.containsKey('or')) {
            return evaluateConditionGroup(recordSObject, 'OR', (List<Object>) mapRule.get('or'));
        }

        return evaluateCondition(recordSObject, mapRule);
    }

    private static Boolean evaluateConditionGroup(SObject recordSObject, String logic, List<Object> conditions) {
        if (conditions == null || conditions.isEmpty()) {
            return true;
        }

        if (String.valueOf(logic).toUpperCase() == 'OR') {
            for (Object item : conditions) {
                if (evaluateCriteriaNode(recordSObject, item)) {
                    return true;
                }
            }
            return false;
        }

        for (Object item : conditions) {
            if (!evaluateCriteriaNode(recordSObject, item)) {
                return false;
            }
        }

        return true;
    }

    private static Boolean evaluateCondition(SObject recordSObject, Map<String, Object> rule) {
        if (rule == null) {
            return true;
        }

        String fieldApiName = (String) rule.get('field');
        String operatorName = String.valueOf(rule.get('operator')).toUpperCase();
        Object expectedValue = rule.get('value');
        Object actualValue = getFieldValue(recordSObject, fieldApiName);

        if (operatorName == 'REQUIRED') {
            return !isBlankValue(actualValue);
        }
        if (operatorName == 'EQUALS') {
            return stringify(actualValue) == stringify(expectedValue);
        }
        if (operatorName == 'NOT_EQUALS') {
            return stringify(actualValue) != stringify(expectedValue);
        }
        if (operatorName == 'TRUE') {
            return actualValue instanceof Boolean && (Boolean) actualValue;
        }
        if (operatorName == 'FALSE') {
            return actualValue instanceof Boolean && !((Boolean) actualValue);
        }
        if (operatorName == 'GREATER_THAN') {
            return compareDecimal(actualValue, expectedValue) > 0;
        }
        if (operatorName == 'LESS_THAN') {
            return compareDecimal(actualValue, expectedValue) < 0;
        }

        return false;
    }

    private static SObject loadRecord(Id recordId) {
        Schema.SObjectType sObjectType = recordId.getSObjectType();
        Schema.DescribeSObjectResult describeResult = sObjectType.getDescribe();
        String objectApiName = describeResult.getName();

        Set<String> fieldNames = new Set<String>{ 'Id', 'CreatedDate' };
        fieldNames.addAll(getReferencedRecordFields(objectApiName));

        List<String> orderedFields = new List<String>();
        orderedFields.addAll(fieldNames);
        orderedFields.sort();

        String soql = 'SELECT ' + String.join(orderedFields, ',') +
            ' FROM ' + objectApiName +
            ' WHERE Id = :recordId';

        return Database.query(soql);
    }

    private static Set<String> getReferencedRecordFields(String objectApiName) {
        if (Test.isRunningTest() && testReferencedFieldOverrides != null) {
            return new Set<String>(testReferencedFieldOverrides);
        }

        Set<String> fields = new Set<String>();

        for (AHA_EasyMilestones_Process_Milestone__mdt milestone : [
            SELECT Start_Field_API_Name__c,
                   Reset_Field_API_Name__c,
                   Extension_Field_API_Name__c
            FROM AHA_EasyMilestones_Process_Milestone__mdt
            WHERE Active__c = true
        ]) {
            if (!String.isBlank(milestone.Start_Field_API_Name__c)) {
                fields.add(milestone.Start_Field_API_Name__c);
            }
            if (!String.isBlank(milestone.Reset_Field_API_Name__c)) {
                fields.add(milestone.Reset_Field_API_Name__c);
            }
            if (!String.isBlank(milestone.Extension_Field_API_Name__c)) {
                fields.add(milestone.Extension_Field_API_Name__c);
            }
        }

        for (AHA_EasyMilestones_Milestone_Validation__mdt validation : [
            SELECT Field_API_Name__c
            FROM AHA_EasyMilestones_Milestone_Validation__mdt
            WHERE Active__c = true
        ]) {
            if (!String.isBlank(validation.Field_API_Name__c)) {
                fields.add(validation.Field_API_Name__c);
            }
        }

        for (AHA_EasyMilestones_Exit_Field_Update__mdt updateConfig : [
            SELECT Field_API_Name__c,
                   Update_Type__c,
                   Update_Value__c
            FROM AHA_EasyMilestones_Exit_Field_Update__mdt
            WHERE Active__c = true
        ]) {
            if (!String.isBlank(updateConfig.Field_API_Name__c)) {
                fields.add(updateConfig.Field_API_Name__c);
            }
            if (String.valueOf(updateConfig.Update_Type__c).toUpperCase() == 'COPY_FIELD'
                && !String.isBlank(updateConfig.Update_Value__c)) {
                fields.add(updateConfig.Update_Value__c);
            }
        }

        for (AHA_EasyMilestones_Entry_Exit_Criteria__mdt criteria : [
            SELECT Criteria_JSON__c
            FROM AHA_EasyMilestones_Entry_Exit_Criteria__mdt
            WHERE Active__c = true
        ]) {
            fields.addAll(extractFieldsFromCriteriaJson(criteria.Criteria_JSON__c));
        }

        Map<String, Schema.SObjectField> availableFields =
            Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();

        Set<String> filtered = new Set<String>();
        for (String fieldName : fields) {
            if (availableFields.containsKey(fieldName)) {
                filtered.add(fieldName);
            }
        }

        return filtered;
    }

    private static Set<String> extractFieldsFromCriteriaJson(String criteriaJson) {
        Set<String> fields = new Set<String>();
        if (String.isBlank(criteriaJson)) {
            return fields;
        }

        try {
            Object parsed = JSON.deserializeUntyped(criteriaJson);
            if (parsed instanceof Map<String, Object>) {
                collectFieldsFromJsonMap((Map<String, Object>) parsed, fields);
            }
        } catch (Exception ex) {
            // ignore malformed JSON
        }

        return fields;
    }

    private static void collectFieldsFromJsonMap(Map<String, Object> node, Set<String> fields) {
        if (node == null) {
            return;
        }

        if (node.containsKey('field') && node.get('field') != null) {
            fields.add(String.valueOf(node.get('field')));
        }

        if (node.containsKey('conditions')) {
            for (Object child : (List<Object>) node.get('conditions')) {
                if (child instanceof Map<String, Object>) {
                    collectFieldsFromJsonMap((Map<String, Object>) child, fields);
                }
            }
        }

        if (node.containsKey('and')) {
            for (Object child : (List<Object>) node.get('and')) {
                if (child instanceof Map<String, Object>) {
                    collectFieldsFromJsonMap((Map<String, Object>) child, fields);
                }
            }
        }

        if (node.containsKey('or')) {
            for (Object child : (List<Object>) node.get('or')) {
                if (child instanceof Map<String, Object>) {
                    collectFieldsFromJsonMap((Map<String, Object>) child, fields);
                }
            }
        }
    }

    private static Object getFieldValue(SObject recordSObject, String fieldApiName) {
        if (String.isBlank(fieldApiName) || !hasField(recordSObject, fieldApiName)) {
            return null;
        }
        return recordSObject.get(fieldApiName);
    }

    private static Datetime getDatetimeValue(SObject recordSObject, String fieldApiName) {
        Object value = getFieldValue(recordSObject, fieldApiName);
        return value instanceof Datetime ? (Datetime) value : null;
    }

    private static Boolean hasField(SObject recordSObject, String fieldApiName) {
        if (recordSObject == null || String.isBlank(fieldApiName)) {
            return false;
        }
        return recordSObject.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName);
    }

    private static Boolean isBlankValue(Object value) {
        if (value == null) {
            return true;
        }
        if (value instanceof String) {
            return String.isBlank((String) value);
        }
        return false;
    }

    private static String stringify(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Integer compareDecimal(Object actualValue, Object expectedValue) {
        Decimal actualDecimal = toDecimal(actualValue);
        Decimal expectedDecimal = toDecimal(expectedValue);

        if (actualDecimal == null || expectedDecimal == null) {
            return 0;
        }
        if (actualDecimal > expectedDecimal) {
            return 1;
        }
        if (actualDecimal < expectedDecimal) {
            return -1;
        }
        return 0;
    }

    private static Decimal toDecimal(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Decimal) {
            return (Decimal) value;
        }
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception ex) {
            return null;
        }
    }

    private static Object coerceValueForField(SObject recordSObject, String fieldApiName, String rawValue) {
        if (!hasField(recordSObject, fieldApiName)) {
            return rawValue;
        }

        Schema.DescribeFieldResult describeField =
            recordSObject.getSObjectType().getDescribe().fields.getMap().get(fieldApiName).getDescribe();

        Schema.DisplayType fieldType = describeField.getType();

        if (String.isBlank(rawValue)) {
            return null;
        }

        try {
            if (fieldType == Schema.DisplayType.Boolean) {
                return 'true'.equalsIgnoreCase(rawValue);
            }
            if (fieldType == Schema.DisplayType.Integer) {
                return Integer.valueOf(rawValue);
            }
            if (fieldType == Schema.DisplayType.Double ||
                fieldType == Schema.DisplayType.Currency ||
                fieldType == Schema.DisplayType.Percent) {
                return Decimal.valueOf(rawValue);
            }
            if (fieldType == Schema.DisplayType.Date) {
                return Date.valueOf(rawValue);
            }
            if (fieldType == Schema.DisplayType.DateTime) {
                return Datetime.valueOf(rawValue);
            }
        } catch (Exception ex) {
            return rawValue;
        }

        return rawValue;
    }

    private static String formatDuration(Long milliseconds) {
        if (milliseconds == null) {
            return 'Awaiting start';
        }

        Long absMs = Math.abs(milliseconds);
        Long totalSeconds = absMs / 1000L;
        Long days = totalSeconds / 86400L;
        Long hours = Math.mod(totalSeconds, 86400L) / 3600L;
        Long minutes = Math.mod(totalSeconds, 3600L) / 60L;

        String prefix = milliseconds < 0 ? 'Overdue by ' : '';
        return prefix + days + 'd ' + hours + 'h ' + minutes + 'm';
    }
}
