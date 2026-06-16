@IsTest
private class AhaEasyMilestonesServiceTest {
    private static final String PROCESS_DEV_NAME = 'CASE_SLA';
    private static final String MILESTONE_SUCCESS = 'FIRST_RESPONSE';
    private static final String MILESTONE_BUSINESS_HOURS = 'BUSINESS_HOURS';
    private static final String MILESTONE_MANUAL_DISABLED = 'MANUAL_DISABLED';
    private static final String MILESTONE_COPY_UPDATE = 'COPY_UPDATE';
    private static final String MILESTONE_NULL_UPDATE = 'NULL_UPDATE';
    private static final String MILESTONE_NOW_COMPLETE = 'NOW_COMPLETE';
    private static final String MILESTONE_TRUE_UPDATE = 'TRUE_UPDATE';
    private static final String MILESTONE_FALSE_UPDATE = 'FALSE_UPDATE';
    private static final String MILESTONE_VALIDATE_TRUE = 'VALIDATE_TRUE';
    private static final String MILESTONE_VALIDATE_FALSE = 'VALIDATE_FALSE';
    private static final String MILESTONE_VALIDATE_GT = 'VALIDATE_GT';
    private static final String MILESTONE_VALIDATE_LT = 'VALIDATE_LT';
    private static final String MILESTONE_COMPLETE_TRUE = 'COMPLETE_TRUE';
    private static final String MILESTONE_COMPLETE_FALSE = 'COMPLETE_FALSE';

    @IsTest
    static void testBuildPanelThrowsWhenRecordIdIsNull() {
        seedOverrides();

        Boolean thrown = false;
        try {
            Test.startTest();
            AhaEasyMilestonesService.buildPanel(null);
            Test.stopTest();
        } catch (Exception ex) {
            thrown = true;
            System.assert(ex instanceof AuraHandledException);
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testMarkCompleteThrowsWhenRecordIdIsNull() {
        seedOverrides();

        Boolean thrown = false;
        try {
            Test.startTest();
            AhaEasyMilestonesService.markComplete(null, MILESTONE_SUCCESS);
            Test.stopTest();
        } catch (Exception ex) {
            thrown = true;
            System.assert(ex instanceof AuraHandledException);
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testMarkCompleteThrowsWhenMilestoneDeveloperNameIsBlank() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Boolean thrown = false;
        try {
            Test.startTest();
            AhaEasyMilestonesService.markComplete(c.Id, null);
            Test.stopTest();
        } catch (Exception ex) {
            thrown = true;
            System.assert(ex instanceof AuraHandledException);
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testBuildPanelReturnsNoConfigForUnsupportedObject() {
        seedOverrides();
        setUnsupportedObjectFieldOverrides();

        Account a = new Account(Name = 'Unsupported Object');
        insert a;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(a.Id);
        Test.stopTest();

        System.assertNotEquals(null, panel);
        System.assertEquals(a.Id, panel.recordId);
        System.assertEquals('No active SLA Process configuration found for this record.', panel.message);
        System.assertEquals(0, panel.milestones.size());
    }

    @IsTest
    static void testMarkCompleteThrowsWhenNoConfigForUnsupportedObject() {
        seedOverrides();
        setUnsupportedObjectFieldOverrides();

        Account a = new Account(Name = 'Unsupported Object');
        insert a;

        Boolean thrown = false;
        try {
            Test.startTest();
            AhaEasyMilestonesService.markComplete(a.Id, MILESTONE_SUCCESS);
            Test.stopTest();
        } catch (Exception ex) {
            thrown = true;
            System.assert(ex instanceof AuraHandledException);
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testBuildPanelReturnsNoActiveSlaMessageWhenEntryCriteriaNotMet() {
        seedOverrides();

        Case c = new Case(
            Subject = 'Entry not met',
            Status = 'Working',
            Origin = 'Phone'
        );
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        System.assertEquals('There are no current active SLA\'s against this record.', panel.message);
    }

    @IsTest
    static void testBuildPanelReturnsExitCriteriaMessage() {
        seedOverrides();

        Case c = new Case(
            Subject = 'Exit met',
            Status = 'Closed',
            Origin = 'Email'
        );
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        System.assertEquals('The record meets SLA exit criteria.', panel.message);
    }

    @IsTest
    static void testBuildPanelReturnsMilestonesForQualifiedRecord() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        System.assertEquals(PROCESS_DEV_NAME, panel.processDeveloperName);
        System.assert(panel.milestones.size() >= 14);
    }

    @IsTest
    static void testBuildPanelReturnsCompletedMilestoneWhenCompletionFieldsAlreadySet() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        c.Subject = 'Completed Subject';
        c.Description = 'Done';
        update c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        Boolean foundCompleted = false;
        for (AhaEasyMilestonesDtos.MilestoneDto milestone : panel.milestones) {
            if (milestone.developerName == MILESTONE_SUCCESS) {
                foundCompleted = true;
                System.assertEquals(true, milestone.completed);
                System.assertEquals('Completed', milestone.status);
                System.assertEquals(0L, milestone.remainingMilliseconds);
            }
        }

        System.assertEquals(true, foundCompleted);
    }

    @IsTest
    static void testBuildPanelUsesCreatedDateFallbackWhenNoExplicitStartValue() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        Boolean found = false;
        for (AhaEasyMilestonesDtos.MilestoneDto milestone : panel.milestones) {
            if (milestone.developerName == MILESTONE_SUCCESS) {
                found = true;
                System.assertNotEquals(null, milestone.startDateTime);
                System.assertNotEquals(null, milestone.targetDateTime);
            }
        }

        System.assertEquals(true, found);
    }

    @IsTest
    static void testBuildPanelExposesBusinessHoursFlagsWhenConfigured() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        Boolean found = false;
        for (AhaEasyMilestonesDtos.MilestoneDto milestone : panel.milestones) {
            if (milestone.developerName == MILESTONE_BUSINESS_HOURS) {
                found = true;
                System.assertEquals(true, milestone.usesBusinessHours);
            }
        }

        System.assertEquals(true, found);
    }

    @IsTest
    static void testBusinessHoursFallbackBranchesAreCovered() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        Boolean found = false;
        for (AhaEasyMilestonesDtos.MilestoneDto milestone : panel.milestones) {
            if (milestone.developerName == MILESTONE_BUSINESS_HOURS) {
                found = true;
                System.assertEquals(true, milestone.usesBusinessHours);
                System.assertNotEquals(null, milestone.startDateTime);
                System.assertNotEquals(null, milestone.targetDateTime);
                System.assertNotEquals(null, milestone.remainingMilliseconds);
                System.assertEquals(true, milestone.businessTimeRunning);
                System.assert(
                    milestone.status == 'Active' || milestone.status == 'Overdue',
                    'Expected BH milestone to resolve to Active or Overdue.'
                );
            }
        }

        System.assertEquals(true, found);
    }

    @IsTest
    static void testBuildPanelCoversNowCompletionBranch() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        Boolean foundCompleted = false;
        for (AhaEasyMilestonesDtos.MilestoneDto milestone : panel.milestones) {
            if (milestone.developerName == MILESTONE_NOW_COMPLETE) {
                foundCompleted = true;
                System.assertEquals(true, milestone.completed);
                System.assertEquals('Completed', milestone.status);
            }
        }

        System.assertEquals(true, foundCompleted);
    }

    @IsTest
    static void testBuildPanelCoversTrueAndFalseCriteriaOperators() {
        seedOverrides();

        AhaEasyMilestonesService.testCriteriaOverrides = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>{
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'ENTRY_FALSE_STATUS_WORKING',
                MasterLabel = 'Entry False Status Working',
                Criteria_Context__c = 'ENTRY',
                Criteria_JSON__c = '{"field":"Status","operator":"EQUALS","value":"Working"}',
                Active__c = true,
                Sequence__c = 1
            ),
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'ENTRY_TRUE_ISCLOSED_FALSE',
                MasterLabel = 'Entry True IsClosed False',
                Criteria_Context__c = 'ENTRY',
                Criteria_JSON__c = '{"field":"IsClosed","operator":"FALSE"}',
                Active__c = true,
                Sequence__c = 2
            ),
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'EXIT_TRUE_ISCLOSED',
                MasterLabel = 'Exit True IsClosed',
                Criteria_Context__c = 'EXIT',
                Criteria_JSON__c = '{"field":"IsClosed","operator":"TRUE"}',
                Active__c = true,
                Sequence__c = 1
            )
        };
        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = new Map<String, String>{
            'ENTRY_FALSE_STATUS_WORKING' => PROCESS_DEV_NAME,
            'ENTRY_TRUE_ISCLOSED_FALSE' => PROCESS_DEV_NAME,
            'EXIT_TRUE_ISCLOSED' => PROCESS_DEV_NAME
        };

        Case openCase = new Case(
            Subject = 'Open case',
            Status = 'New',
            Origin = 'Phone'
        );
        insert openCase;

        AhaEasyMilestonesDtos.PanelDto openPanel = AhaEasyMilestonesService.buildPanel(openCase.Id);
        System.assertEquals(null, openPanel.message);

        AhaEasyMilestonesService.testCriteriaOverrides = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>{
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'ENTRY_TRUE_STATUS_CLOSED',
                MasterLabel = 'Entry True Status Closed',
                Criteria_Context__c = 'ENTRY',
                Criteria_JSON__c = '{"field":"Status","operator":"EQUALS","value":"Closed"}',
                Active__c = true,
                Sequence__c = 1
            ),
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'EXIT_TRUE_ISCLOSED_ONLY',
                MasterLabel = 'Exit True IsClosed Only',
                Criteria_Context__c = 'EXIT',
                Criteria_JSON__c = '{"field":"IsClosed","operator":"TRUE"}',
                Active__c = true,
                Sequence__c = 1
            )
        };
        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = new Map<String, String>{
            'ENTRY_TRUE_STATUS_CLOSED' => PROCESS_DEV_NAME,
            'EXIT_TRUE_ISCLOSED_ONLY' => PROCESS_DEV_NAME
        };

        Case closedCase = new Case(
            Subject = 'Closed case',
            Status = 'Closed',
            Origin = 'Phone'
        );
        insert closedCase;

        AhaEasyMilestonesDtos.PanelDto closedPanel = AhaEasyMilestonesService.buildPanel(closedCase.Id);
        System.assertEquals('The record meets SLA exit criteria.', closedPanel.message);
    }

    @IsTest
    static void testBuildPanelCoversGreaterThanAndLessThanCriteriaOperators() {
        seedOverrides();

        AhaEasyMilestonesService.testCriteriaOverrides = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>{
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'ENTRY_GT_CASE_NUMBER',
                MasterLabel = 'Entry Greater Than',
                Criteria_Context__c = 'ENTRY',
                Criteria_JSON__c = '{"field":"CaseNumber","operator":"GREATER_THAN","value":"0"}',
                Active__c = true,
                Sequence__c = 1
            ),
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'EXIT_LT_CASE_NUMBER',
                MasterLabel = 'Exit Less Than',
                Criteria_Context__c = 'EXIT',
                Criteria_JSON__c = '{"field":"CaseNumber","operator":"LESS_THAN","value":"0"}',
                Active__c = true,
                Sequence__c = 1
            )
        };
        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = new Map<String, String>{
            'ENTRY_GT_CASE_NUMBER' => PROCESS_DEV_NAME,
            'EXIT_LT_CASE_NUMBER' => PROCESS_DEV_NAME
        };

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        System.assertEquals(null, panel.message);
        System.assert(panel.milestones.size() > 0);
    }

    @IsTest
    static void testBuildPanelCoversDefaultCriteriaBehaviorWhenNoCriteriaExist() {
        seedOverrides();
        AhaEasyMilestonesService.testCriteriaOverrides = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>();
        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = new Map<String, String>();

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, panel);
        System.assertEquals(PROCESS_DEV_NAME, panel.processDeveloperName);
        System.assert(panel.milestones.size() > 0);
    }

    @IsTest
    static void testBuildPanelHandlesMalformedCriteriaJson() {
        seedOverrides();

        AhaEasyMilestonesService.testCriteriaOverrides = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>{
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'ENTRY_BAD_JSON',
                MasterLabel = 'Entry Bad Json',
                Criteria_Context__c = 'ENTRY',
                Criteria_JSON__c = '{"logic":"OR","conditions":[',
                Active__c = true,
                Sequence__c = 1
            )
        };
        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = new Map<String, String>{
            'ENTRY_BAD_JSON' => PROCESS_DEV_NAME
        };

        Case c = buildQualifiedCase();
        insert c;

        Boolean thrown = false;
        try {
            Test.startTest();
            AhaEasyMilestonesService.buildPanel(c.Id);
            Test.stopTest();
        } catch (Exception ex) {
            thrown = true;
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testBuildPanelCoversUnknownCriteriaOperatorBranch() {
        seedOverrides();

        AhaEasyMilestonesService.testCriteriaOverrides = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>{
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'ENTRY_UNKNOWN_OPERATOR',
                MasterLabel = 'Entry Unknown Operator',
                Criteria_Context__c = 'ENTRY',
                Criteria_JSON__c = '{"field":"Status","operator":"BOGUS","value":"New"}',
                Active__c = true,
                Sequence__c = 1
            )
        };
        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = new Map<String, String>{
            'ENTRY_UNKNOWN_OPERATOR' => PROCESS_DEV_NAME
        };

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        System.assertEquals('There are no current active SLA\'s against this record.', panel.message);
    }

    @IsTest
    static void testBuildPanelCoversLegacyAndJsonShape() {
        seedOverrides();

        AhaEasyMilestonesService.testCriteriaOverrides = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>{
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'ENTRY_LEGACY_AND',
                MasterLabel = 'Entry Legacy And',
                Criteria_Context__c = 'ENTRY',
                Criteria_JSON__c = '{"and":[{"field":"Origin","operator":"EQUALS","value":"Phone"},{"field":"Status","operator":"EQUALS","value":"New"}]}',
                Active__c = true,
                Sequence__c = 1
            ),
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'EXIT_LEGACY_OR',
                MasterLabel = 'Exit Legacy Or',
                Criteria_Context__c = 'EXIT',
                Criteria_JSON__c = '{"or":[{"field":"Status","operator":"EQUALS","value":"Closed"},{"field":"Origin","operator":"EQUALS","value":"Email"}]}',
                Active__c = true,
                Sequence__c = 1
            )
        };
        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = new Map<String, String>{
            'ENTRY_LEGACY_AND' => PROCESS_DEV_NAME,
            'EXIT_LEGACY_OR' => PROCESS_DEV_NAME
        };

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        System.assertEquals(null, panel.message);
        System.assert(panel.milestones.size() > 0);
    }

    @IsTest
    static void testBuildPanelCoversRowLevelOrAcrossEntryCriteria() {
        seedOverrides();

        AhaEasyMilestonesService.testCriteriaOverrides = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>{
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'ENTRY_ROW_FALSE',
                MasterLabel = 'Entry Row False',
                Criteria_Context__c = 'ENTRY',
                Criteria_JSON__c = '{"field":"Status","operator":"EQUALS","value":"Working"}',
                Active__c = true,
                Sequence__c = 1
            ),
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'ENTRY_ROW_TRUE',
                MasterLabel = 'Entry Row True',
                Criteria_Context__c = 'ENTRY',
                Criteria_JSON__c = '{"field":"Origin","operator":"EQUALS","value":"Phone"}',
                Active__c = true,
                Sequence__c = 2
            )
        };
        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = new Map<String, String>{
            'ENTRY_ROW_FALSE' => PROCESS_DEV_NAME,
            'ENTRY_ROW_TRUE' => PROCESS_DEV_NAME
        };

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        System.assertEquals(null, panel.message);
        System.assert(panel.milestones.size() > 0);
    }

    @IsTest
    static void testBuildPanelCoversRowLevelOrAcrossExitCriteria() {
        seedOverrides();

        AhaEasyMilestonesService.testCriteriaOverrides = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>{
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'ENTRY_ALWAYS_TRUE',
                MasterLabel = 'Entry Always True',
                Criteria_Context__c = 'ENTRY',
                Criteria_JSON__c = '{"field":"Origin","operator":"EQUALS","value":"Phone"}',
                Active__c = true,
                Sequence__c = 1
            ),
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'EXIT_ROW_FALSE',
                MasterLabel = 'Exit Row False',
                Criteria_Context__c = 'EXIT',
                Criteria_JSON__c = '{"field":"Status","operator":"EQUALS","value":"Working"}',
                Active__c = true,
                Sequence__c = 1
            ),
            new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
                DeveloperName = 'EXIT_ROW_TRUE',
                MasterLabel = 'Exit Row True',
                Criteria_Context__c = 'EXIT',
                Criteria_JSON__c = '{"field":"Status","operator":"EQUALS","value":"Closed"}',
                Active__c = true,
                Sequence__c = 2
            )
        };
        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = new Map<String, String>{
            'ENTRY_ALWAYS_TRUE' => PROCESS_DEV_NAME,
            'EXIT_ROW_FALSE' => PROCESS_DEV_NAME,
            'EXIT_ROW_TRUE' => PROCESS_DEV_NAME
        };

        Case c = new Case(
            Subject = 'Closed case',
            Status = 'Closed',
            Origin = 'Phone'
        );
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        System.assertEquals('The record meets SLA exit criteria.', panel.message);
    }

    @IsTest
    static void testBuildPanelCoversBooleanCompletionDetectionBranches() {
        seedOverrides();

        Case c = buildQualifiedCase();
        c.IsEscalated = true;
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.PanelDto panel = AhaEasyMilestonesService.buildPanel(c.Id);
        Test.stopTest();

        Boolean foundTrueCompleted = false;
        Boolean foundFalseNotCompleted = false;

        for (AhaEasyMilestonesDtos.MilestoneDto milestone : panel.milestones) {
            if (milestone.developerName == MILESTONE_COMPLETE_TRUE) {
                foundTrueCompleted = true;
                System.assertEquals(true, milestone.completed);
            }
            if (milestone.developerName == MILESTONE_COMPLETE_FALSE) {
                foundFalseNotCompleted = true;
                System.assertEquals(false, milestone.completed);
            }
        }

        System.assertEquals(true, foundTrueCompleted);
        System.assertEquals(true, foundFalseNotCompleted);
    }

    @IsTest
    static void testMarkCompleteThrowsWhenMilestoneNotFound() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Boolean thrown = false;
        try {
            Test.startTest();
            AhaEasyMilestonesService.markComplete(c.Id, 'DOES_NOT_EXIST');
            Test.stopTest();
        } catch (Exception ex) {
            thrown = true;
            System.assert(ex instanceof AuraHandledException);
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testMarkCompleteThrowsWhenManualCompletionDisabled() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Boolean thrown = false;
        try {
            Test.startTest();
            AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_MANUAL_DISABLED);
            Test.stopTest();
        } catch (Exception ex) {
            thrown = true;
            System.assert(ex instanceof AuraHandledException);
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testMarkCompleteValidationFailure() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        c.Subject = null;
        update c;

        Test.startTest();
        AhaEasyMilestonesDtos.ActionResultDto result =
            AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_SUCCESS);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.message);
        System.assertNotEquals(null, result.panel);
    }

    @IsTest
    static void testMarkCompleteHandlesBlankValidationJson() {
        seedOverrides();

        AhaEasyMilestonesService.testValidationOverrides.add(
            new AHA_EasyMilestones_Milestone_Validation__mdt(
                DeveloperName = 'VAL_BLANK_JSON',
                MasterLabel = 'Blank Json',
                Field_API_Name__c = 'Subject',
                Validation_Rule_JSON__c = null,
                Error_Message__c = 'Should not fire',
                Active__c = true,
                Sequence__c = 99
            )
        );
        AhaEasyMilestonesService.testValidationToMilestoneDeveloperName.put(
            'VAL_BLANK_JSON',
            MILESTONE_SUCCESS
        );

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.ActionResultDto result =
            AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_SUCCESS);
        Test.stopTest();

        System.assertEquals(true, result.success);
    }

    @IsTest
    static void testMarkCompleteCoversUnknownValidationTypeBranch() {
        seedOverrides();

        AhaEasyMilestonesService.testValidationOverrides = new List<AHA_EasyMilestones_Milestone_Validation__mdt>{
            new AHA_EasyMilestones_Milestone_Validation__mdt(
                DeveloperName = 'VAL_UNKNOWN_TYPE',
                MasterLabel = 'Unknown Type',
                Field_API_Name__c = 'Subject',
                Validation_Rule_JSON__c = '{"type":"BOGUS","value":"Anything"}',
                Error_Message__c = 'Should not fire',
                Active__c = true,
                Sequence__c = 1
            )
        };
        AhaEasyMilestonesService.testValidationToMilestoneDeveloperName = new Map<String, String>{
            'VAL_UNKNOWN_TYPE' => MILESTONE_SUCCESS
        };

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.ActionResultDto result =
            AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_SUCCESS);
        Test.stopTest();

        System.assertEquals(true, result.success);
    }

    @IsTest
    static void testMarkCompleteValidationTrueOperatorFailure() {
        seedOverrides();

        Case c = buildQualifiedCase();
        c.Status = 'New';
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.ActionResultDto result =
            AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_VALIDATE_TRUE);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.message);
    }

    @IsTest
    static void testMarkCompleteValidationFalseOperatorFailure() {
        seedOverrides();

        Case c = buildQualifiedCase();
        c.Status = 'Closed';
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.ActionResultDto result =
            AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_VALIDATE_FALSE);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.message);
    }

    @IsTest
    static void testMarkCompleteValidationGreaterThanFailure() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.ActionResultDto result =
            AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_VALIDATE_GT);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.message);
    }

    @IsTest
    static void testMarkCompleteValidationLessThanFailure() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.ActionResultDto result =
            AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_VALIDATE_LT);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.message);
    }

    @IsTest
    static void testMarkCompleteSuccess() {
        seedOverrides();

        Case c = buildQualifiedCase();
        insert c;

        Test.startTest();
        AhaEasyMilestonesDtos.ActionResultDto result =
            AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_SUCCESS);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('Milestone marked complete.', result.message);

        Case updatedCase = [
            SELECT Subject, Description
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals('Completed Subject', updatedCase.Subject);
        System.assertEquals('Done', updatedCase.Description);
    }

    @IsTest
    static void testMarkCompleteCoversCopyFieldBranch() {
        seedOverrides();

        Case c = buildQualifiedCase();
        c.Subject = 'Copied Value';
        insert c;

        Test.startTest();
        AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_COPY_UPDATE);
        Test.stopTest();

        Case updatedCase = [
            SELECT Subject, Description
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals('Copied Value', updatedCase.Description);
    }

    @IsTest
    static void testMarkCompleteCoversNullBranch() {
        seedOverrides();

        Case c = buildQualifiedCase();
        c.Description = 'Will be nulled';
        insert c;

        Test.startTest();
        AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_NULL_UPDATE);
        Test.stopTest();

        Case updatedCase = [
            SELECT Description
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(null, updatedCase.Description);
    }

    @IsTest
    static void testMarkCompleteCoversTrueUpdateBranch() {
        seedOverrides();

        Case c = buildQualifiedCase();
        c.IsEscalated = false;
        insert c;

        Test.startTest();
        AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_TRUE_UPDATE);
        Test.stopTest();

        Case updatedCase = [
            SELECT IsEscalated
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(true, updatedCase.IsEscalated);
    }

    @IsTest
    static void testMarkCompleteCoversFalseUpdateBranch() {
        seedOverrides();

        Case c = buildQualifiedCase();
        c.IsEscalated = true;
        insert c;

        Test.startTest();
        AhaEasyMilestonesService.markComplete(c.Id, MILESTONE_FALSE_UPDATE);
        Test.stopTest();

        Case updatedCase = [
            SELECT IsEscalated
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(false, updatedCase.IsEscalated);
    }

    private static void seedOverrides() {
        resetOverrides();

        AHA_EasyMilestones_Process__mdt processRow = new AHA_EasyMilestones_Process__mdt(
            DeveloperName = PROCESS_DEV_NAME,
            MasterLabel = 'Case SLA',
            Target_Object_API_Name__c = 'Case',
            Active__c = true
        );
        AhaEasyMilestonesService.testProcessOverride = processRow;

        AHA_EasyMilestones_Process_Milestone__mdt successMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_SUCCESS,
            MasterLabel = 'First Response',
            Description__c = 'Primary milestone',
            Time_Trigger_Minutes__c = 60,
            Manual_Completion_Enabled__c = true,
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Process_Milestone__mdt bhMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_BUSINESS_HOURS,
            MasterLabel = 'Business Hours',
            Description__c = 'Business hours milestone',
            Time_Trigger_Minutes__c = 30,
            Extension_Enabled__c = true,
            Extension_Field_API_Name__c = 'Subject',
            Manual_Completion_Enabled__c = true,
            Business_Hours_Id_Override__c = 'DUMMY_BH',
            Active__c = true,
            Sequence__c = 2
        );

        AHA_EasyMilestones_Process_Milestone__mdt manualDisabledMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_MANUAL_DISABLED,
            MasterLabel = 'Manual Disabled',
            Description__c = 'Manual disabled milestone',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = false,
            Active__c = true,
            Sequence__c = 3
        );

        AHA_EasyMilestones_Process_Milestone__mdt copyMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_COPY_UPDATE,
            MasterLabel = 'Copy Update',
            Description__c = 'Copy field branch',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = true,
            Active__c = true,
            Sequence__c = 4
        );

        AHA_EasyMilestones_Process_Milestone__mdt nullMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_NULL_UPDATE,
            MasterLabel = 'Null Update',
            Description__c = 'Null branch',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = true,
            Active__c = true,
            Sequence__c = 5
        );

        AHA_EasyMilestones_Process_Milestone__mdt nowCompleteMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_NOW_COMPLETE,
            MasterLabel = 'Now Complete',
            Description__c = 'NOW completion detection',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = false,
            Active__c = true,
            Sequence__c = 6
        );

        AHA_EasyMilestones_Process_Milestone__mdt trueUpdateMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_TRUE_UPDATE,
            MasterLabel = 'True Update',
            Description__c = 'TRUE update branch',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = true,
            Active__c = true,
            Sequence__c = 7
        );

        AHA_EasyMilestones_Process_Milestone__mdt falseUpdateMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_FALSE_UPDATE,
            MasterLabel = 'False Update',
            Description__c = 'FALSE update branch',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = true,
            Active__c = true,
            Sequence__c = 8
        );

        AHA_EasyMilestones_Process_Milestone__mdt validateTrueMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_VALIDATE_TRUE,
            MasterLabel = 'Validate True',
            Description__c = 'TRUE validation branch',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = true,
            Active__c = true,
            Sequence__c = 9
        );

        AHA_EasyMilestones_Process_Milestone__mdt validateFalseMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_VALIDATE_FALSE,
            MasterLabel = 'Validate False',
            Description__c = 'FALSE validation branch',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = true,
            Active__c = true,
            Sequence__c = 10
        );

        AHA_EasyMilestones_Process_Milestone__mdt validateGtMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_VALIDATE_GT,
            MasterLabel = 'Validate GT',
            Description__c = 'GREATER_THAN validation branch',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = true,
            Active__c = true,
            Sequence__c = 11
        );

        AHA_EasyMilestones_Process_Milestone__mdt validateLtMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_VALIDATE_LT,
            MasterLabel = 'Validate LT',
            Description__c = 'LESS_THAN validation branch',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = true,
            Active__c = true,
            Sequence__c = 12
        );

        AHA_EasyMilestones_Process_Milestone__mdt completeTrueMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_COMPLETE_TRUE,
            MasterLabel = 'Complete True',
            Description__c = 'TRUE completion detection',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = false,
            Active__c = true,
            Sequence__c = 13
        );

        AHA_EasyMilestones_Process_Milestone__mdt completeFalseMilestone = new AHA_EasyMilestones_Process_Milestone__mdt(
            DeveloperName = MILESTONE_COMPLETE_FALSE,
            MasterLabel = 'Complete False',
            Description__c = 'FALSE completion detection',
            Time_Trigger_Minutes__c = 15,
            Manual_Completion_Enabled__c = false,
            Active__c = true,
            Sequence__c = 14
        );

        AhaEasyMilestonesService.testMilestoneOverrides = new List<AHA_EasyMilestones_Process_Milestone__mdt>{
            successMilestone,
            bhMilestone,
            manualDisabledMilestone,
            copyMilestone,
            nullMilestone,
            nowCompleteMilestone,
            trueUpdateMilestone,
            falseUpdateMilestone,
            validateTrueMilestone,
            validateFalseMilestone,
            validateGtMilestone,
            validateLtMilestone,
            completeTrueMilestone,
            completeFalseMilestone
        };

        AhaEasyMilestonesService.testMilestoneToProcessDeveloperName = new Map<String, String>{
            MILESTONE_SUCCESS => PROCESS_DEV_NAME,
            MILESTONE_BUSINESS_HOURS => PROCESS_DEV_NAME,
            MILESTONE_MANUAL_DISABLED => PROCESS_DEV_NAME,
            MILESTONE_COPY_UPDATE => PROCESS_DEV_NAME,
            MILESTONE_NULL_UPDATE => PROCESS_DEV_NAME,
            MILESTONE_NOW_COMPLETE => PROCESS_DEV_NAME,
            MILESTONE_TRUE_UPDATE => PROCESS_DEV_NAME,
            MILESTONE_FALSE_UPDATE => PROCESS_DEV_NAME,
            MILESTONE_VALIDATE_TRUE => PROCESS_DEV_NAME,
            MILESTONE_VALIDATE_FALSE => PROCESS_DEV_NAME,
            MILESTONE_VALIDATE_GT => PROCESS_DEV_NAME,
            MILESTONE_VALIDATE_LT => PROCESS_DEV_NAME,
            MILESTONE_COMPLETE_TRUE => PROCESS_DEV_NAME,
            MILESTONE_COMPLETE_FALSE => PROCESS_DEV_NAME
        };

        AHA_EasyMilestones_Milestone_Validation__mdt valRequired = new AHA_EasyMilestones_Milestone_Validation__mdt(
            DeveloperName = 'VAL_REQUIRED_SUBJECT',
            MasterLabel = 'Subject Required',
            Field_API_Name__c = 'Subject',
            Validation_Rule_JSON__c = '{"type":"REQUIRED"}',
            Error_Message__c = 'Subject must be populated.',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Milestone_Validation__mdt valEquals = new AHA_EasyMilestones_Milestone_Validation__mdt(
            DeveloperName = 'VAL_EQUALS_ORIGIN',
            MasterLabel = 'Origin Equals Phone',
            Field_API_Name__c = 'Origin',
            Validation_Rule_JSON__c = '{"type":"EQUALS","value":"Phone"}',
            Error_Message__c = 'Origin must be Phone.',
            Active__c = true,
            Sequence__c = 2
        );

        AHA_EasyMilestones_Milestone_Validation__mdt valNotEquals = new AHA_EasyMilestones_Milestone_Validation__mdt(
            DeveloperName = 'VAL_NOT_EQUALS_STATUS',
            MasterLabel = 'Status Not Closed',
            Field_API_Name__c = 'Status',
            Validation_Rule_JSON__c = '{"type":"NOT_EQUALS","value":"Closed"}',
            Error_Message__c = 'Status must not be Closed.',
            Active__c = true,
            Sequence__c = 3
        );

        AHA_EasyMilestones_Milestone_Validation__mdt valTrue = new AHA_EasyMilestones_Milestone_Validation__mdt(
            DeveloperName = 'VAL_TRUE_ISCLOSED',
            MasterLabel = 'IsClosed True',
            Field_API_Name__c = 'IsClosed',
            Validation_Rule_JSON__c = '{"type":"TRUE"}',
            Error_Message__c = 'Case must be closed.',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Milestone_Validation__mdt valFalse = new AHA_EasyMilestones_Milestone_Validation__mdt(
            DeveloperName = 'VAL_FALSE_ISCLOSED',
            MasterLabel = 'IsClosed False',
            Field_API_Name__c = 'IsClosed',
            Validation_Rule_JSON__c = '{"type":"FALSE"}',
            Error_Message__c = 'Case must be open.',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Milestone_Validation__mdt valGt = new AHA_EasyMilestones_Milestone_Validation__mdt(
            DeveloperName = 'VAL_GT_CASE_NUMBER',
            MasterLabel = 'CaseNumber GT',
            Field_API_Name__c = 'CaseNumber',
            Validation_Rule_JSON__c = '{"type":"GREATER_THAN","value":"999999999"}',
            Error_Message__c = 'CaseNumber must be greater.',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Milestone_Validation__mdt valLt = new AHA_EasyMilestones_Milestone_Validation__mdt(
            DeveloperName = 'VAL_LT_CASE_NUMBER',
            MasterLabel = 'CaseNumber LT',
            Field_API_Name__c = 'CaseNumber',
            Validation_Rule_JSON__c = '{"type":"LESS_THAN","value":"0"}',
            Error_Message__c = 'CaseNumber must be less.',
            Active__c = true,
            Sequence__c = 1
        );

        AhaEasyMilestonesService.testValidationOverrides = new List<AHA_EasyMilestones_Milestone_Validation__mdt>{
            valRequired, valEquals, valNotEquals, valTrue, valFalse, valGt, valLt
        };

        AhaEasyMilestonesService.testValidationToMilestoneDeveloperName = new Map<String, String>{
            'VAL_REQUIRED_SUBJECT' => MILESTONE_SUCCESS,
            'VAL_EQUALS_ORIGIN' => MILESTONE_SUCCESS,
            'VAL_NOT_EQUALS_STATUS' => MILESTONE_SUCCESS,
            'VAL_TRUE_ISCLOSED' => MILESTONE_VALIDATE_TRUE,
            'VAL_FALSE_ISCLOSED' => MILESTONE_VALIDATE_FALSE,
            'VAL_GT_CASE_NUMBER' => MILESTONE_VALIDATE_GT,
            'VAL_LT_CASE_NUMBER' => MILESTONE_VALIDATE_LT
        };

        AHA_EasyMilestones_Exit_Field_Update__mdt successUpdate1 = new AHA_EasyMilestones_Exit_Field_Update__mdt(
            DeveloperName = 'UPD_SUCCESS_SUBJECT',
            MasterLabel = 'Set Subject',
            Update_Context__c = 'MILESTONE_COMPLETE',
            Field_API_Name__c = 'Subject',
            Update_Type__c = 'STATIC',
            Update_Value__c = 'Completed Subject',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Exit_Field_Update__mdt successUpdate2 = new AHA_EasyMilestones_Exit_Field_Update__mdt(
            DeveloperName = 'UPD_SUCCESS_DESCRIPTION',
            MasterLabel = 'Set Description',
            Update_Context__c = 'MILESTONE_COMPLETE',
            Field_API_Name__c = 'Description',
            Update_Type__c = 'STATIC',
            Update_Value__c = 'Done',
            Active__c = true,
            Sequence__c = 2
        );

        AHA_EasyMilestones_Exit_Field_Update__mdt copyUpdate = new AHA_EasyMilestones_Exit_Field_Update__mdt(
            DeveloperName = 'UPD_COPY_DESCRIPTION',
            MasterLabel = 'Copy Subject',
            Update_Context__c = 'MILESTONE_COMPLETE',
            Field_API_Name__c = 'Description',
            Update_Type__c = 'COPY_FIELD',
            Update_Value__c = 'Subject',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Exit_Field_Update__mdt nullUpdate = new AHA_EasyMilestones_Exit_Field_Update__mdt(
            DeveloperName = 'UPD_NULL_DESCRIPTION',
            MasterLabel = 'Null Description',
            Update_Context__c = 'MILESTONE_COMPLETE',
            Field_API_Name__c = 'Description',
            Update_Type__c = 'NULL',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Exit_Field_Update__mdt nowCompleteUpdate = new AHA_EasyMilestones_Exit_Field_Update__mdt(
            DeveloperName = 'UPD_NOW_CREATEDDATE',
            MasterLabel = 'Now CreatedDate',
            Update_Context__c = 'MILESTONE_COMPLETE',
            Field_API_Name__c = 'CreatedDate',
            Update_Type__c = 'NOW',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Exit_Field_Update__mdt trueUpdate = new AHA_EasyMilestones_Exit_Field_Update__mdt(
            DeveloperName = 'UPD_TRUE_ESCALATED',
            MasterLabel = 'True Escalated',
            Update_Context__c = 'MILESTONE_COMPLETE',
            Field_API_Name__c = 'IsEscalated',
            Update_Type__c = 'TRUE',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Exit_Field_Update__mdt falseUpdate = new AHA_EasyMilestones_Exit_Field_Update__mdt(
            DeveloperName = 'UPD_FALSE_ESCALATED',
            MasterLabel = 'False Escalated',
            Update_Context__c = 'MILESTONE_COMPLETE',
            Field_API_Name__c = 'IsEscalated',
            Update_Type__c = 'FALSE',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Exit_Field_Update__mdt completeTrueUpdate = new AHA_EasyMilestones_Exit_Field_Update__mdt(
            DeveloperName = 'UPD_COMPLETE_TRUE_ESCALATED',
            MasterLabel = 'Complete True Escalated',
            Update_Context__c = 'MILESTONE_COMPLETE',
            Field_API_Name__c = 'IsEscalated',
            Update_Type__c = 'TRUE',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Exit_Field_Update__mdt completeFalseUpdate = new AHA_EasyMilestones_Exit_Field_Update__mdt(
            DeveloperName = 'UPD_COMPLETE_FALSE_ESCALATED',
            MasterLabel = 'Complete False Escalated',
            Update_Context__c = 'MILESTONE_COMPLETE',
            Field_API_Name__c = 'IsEscalated',
            Update_Type__c = 'FALSE',
            Active__c = true,
            Sequence__c = 1
        );

        AhaEasyMilestonesService.testExitUpdateOverrides = new List<AHA_EasyMilestones_Exit_Field_Update__mdt>{
            successUpdate1,
            successUpdate2,
            copyUpdate,
            nullUpdate,
            nowCompleteUpdate,
            trueUpdate,
            falseUpdate,
            completeTrueUpdate,
            completeFalseUpdate
        };

        AhaEasyMilestonesService.testExitUpdateToMilestoneDeveloperName = new Map<String, String>{
            'UPD_SUCCESS_SUBJECT' => MILESTONE_SUCCESS,
            'UPD_SUCCESS_DESCRIPTION' => MILESTONE_SUCCESS,
            'UPD_COPY_DESCRIPTION' => MILESTONE_COPY_UPDATE,
            'UPD_NULL_DESCRIPTION' => MILESTONE_NULL_UPDATE,
            'UPD_NOW_CREATEDDATE' => MILESTONE_NOW_COMPLETE,
            'UPD_TRUE_ESCALATED' => MILESTONE_TRUE_UPDATE,
            'UPD_FALSE_ESCALATED' => MILESTONE_FALSE_UPDATE,
            'UPD_COMPLETE_TRUE_ESCALATED' => MILESTONE_COMPLETE_TRUE,
            'UPD_COMPLETE_FALSE_ESCALATED' => MILESTONE_COMPLETE_FALSE
        };

        AHA_EasyMilestones_Entry_Exit_Criteria__mdt entryCriteria = new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
            DeveloperName = 'ENTRY_OR',
            MasterLabel = 'Entry OR',
            Criteria_Context__c = 'ENTRY',
            Criteria_JSON__c = '{"logic":"OR","conditions":[{"field":"Status","operator":"EQUALS","value":"New"},{"field":"Origin","operator":"EQUALS","value":"Email"}]}',
            Active__c = true,
            Sequence__c = 1
        );

        AHA_EasyMilestones_Entry_Exit_Criteria__mdt exitCriteria = new AHA_EasyMilestones_Entry_Exit_Criteria__mdt(
            DeveloperName = 'EXIT_STATUS',
            MasterLabel = 'Exit Closed',
            Criteria_Context__c = 'EXIT',
            Criteria_JSON__c = '{"field":"Status","operator":"EQUALS","value":"Closed"}',
            Active__c = true,
            Sequence__c = 1
        );

        AhaEasyMilestonesService.testCriteriaOverrides = new List<AHA_EasyMilestones_Entry_Exit_Criteria__mdt>{
            entryCriteria, exitCriteria
        };

        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = new Map<String, String>{
            'ENTRY_OR' => PROCESS_DEV_NAME,
            'EXIT_STATUS' => PROCESS_DEV_NAME
        };

        AhaEasyMilestonesService.testReferencedFieldOverrides = new Set<String>{
            'Subject', 'Status', 'Origin', 'Description', 'IsEscalated', 'IsClosed', 'CaseNumber'
        };
    }

    private static void setUnsupportedObjectFieldOverrides() {
        AhaEasyMilestonesService.testReferencedFieldOverrides = new Set<String>{ 'Name' };
    }

    private static void resetOverrides() {
        AhaEasyMilestonesService.testProcessOverride = null;
        AhaEasyMilestonesService.testMilestoneOverrides = null;
        AhaEasyMilestonesService.testValidationOverrides = null;
        AhaEasyMilestonesService.testExitUpdateOverrides = null;
        AhaEasyMilestonesService.testCriteriaOverrides = null;
        AhaEasyMilestonesService.testReferencedFieldOverrides = null;

        AhaEasyMilestonesService.testMilestoneToProcessDeveloperName = null;
        AhaEasyMilestonesService.testValidationToMilestoneDeveloperName = null;
        AhaEasyMilestonesService.testExitUpdateToMilestoneDeveloperName = null;
        AhaEasyMilestonesService.testCriteriaToProcessDeveloperName = null;
    }

    private static Case buildQualifiedCase() {
        return new Case(
            Subject = 'Initial Subject',
            Status = 'New',
            Origin = 'Phone',
            Description = 'Initial Description'
        );
    }
}
