@IsTest
private class AhaEasyMilestonesDtosTest {
    @IsTest
    static void testPanelDtoDefaultsAndAssignments() {
        AhaEasyMilestonesDtos.PanelDto panel = new AhaEasyMilestonesDtos.PanelDto();
        panel.processDeveloperName = 'Case_SLA_Test';
        panel.processLabel = 'Case SLA Test';
        panel.message = 'Test message';

        System.assertEquals('Case_SLA_Test', panel.processDeveloperName);
        System.assertEquals('Case SLA Test', panel.processLabel);
        System.assertEquals('Test message', panel.message);
        System.assertNotEquals(null, panel.milestones);
        System.assertEquals(0, panel.milestones.size());
        System.assertEquals(null, panel.recordId);
    }

    @IsTest
    static void testMilestoneDtoAssignments() {
        AhaEasyMilestonesDtos.MilestoneDto milestone = new AhaEasyMilestonesDtos.MilestoneDto();

        Datetime startDt = Datetime.newInstance(2026, 4, 13, 9, 0, 0);
        Datetime targetDt = Datetime.newInstance(2026, 4, 18, 17, 0, 0);

        milestone.developerName = 'SLA_Test_Start_End_Milestone';
        milestone.label = 'SLA Test Start End Milestone';
        milestone.description = 'Test milestone description';
        milestone.sequence = 1;
        milestone.manualCompletionEnabled = true;
        milestone.completed = false;
        milestone.overdue = false;
        milestone.businessTimeRunning = true;
        milestone.usesBusinessHours = true;
        milestone.status = 'Active';
        milestone.startDateTime = startDt;
        milestone.targetDateTime = targetDt;
        milestone.remainingMilliseconds = 123456L;
        milestone.displayText = '5d 00:00:00 remaining';

        System.assertEquals('SLA_Test_Start_End_Milestone', milestone.developerName);
        System.assertEquals('SLA Test Start End Milestone', milestone.label);
        System.assertEquals('Test milestone description', milestone.description);
        System.assertEquals(1, milestone.sequence);
        System.assertEquals(true, milestone.manualCompletionEnabled);
        System.assertEquals(false, milestone.completed);
        System.assertEquals(false, milestone.overdue);
        System.assertEquals(true, milestone.businessTimeRunning);
        System.assertEquals(true, milestone.usesBusinessHours);
        System.assertEquals('Active', milestone.status);
        System.assertEquals(startDt, milestone.startDateTime);
        System.assertEquals(targetDt, milestone.targetDateTime);
        System.assertEquals(123456L, milestone.remainingMilliseconds);
        System.assertEquals('5d 00:00:00 remaining', milestone.displayText);
    }

    @IsTest
    static void testActionResultDtoAssignments() {
        AhaEasyMilestonesDtos.PanelDto panel = new AhaEasyMilestonesDtos.PanelDto();
        panel.message = 'Panel message';

        AhaEasyMilestonesDtos.ActionResultDto result = new AhaEasyMilestonesDtos.ActionResultDto();
        result.success = true;
        result.message = 'Milestone marked complete.';
        result.panel = panel;

        System.assertEquals(true, result.success);
        System.assertEquals('Milestone marked complete.', result.message);
        System.assertNotEquals(null, result.panel);
        System.assertEquals('Panel message', result.panel.message);
    }
}
