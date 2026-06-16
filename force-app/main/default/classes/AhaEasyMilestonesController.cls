public with sharing class AhaEasyMilestonesController {
    @AuraEnabled(cacheable=true)
    public static AhaEasyMilestonesDtos.PanelDto getMilestones(Id recordId) {
        return AhaEasyMilestonesService.buildPanel(recordId);
    }

    @AuraEnabled
    public static AhaEasyMilestonesDtos.ActionResultDto markComplete(Id recordId, String milestoneDeveloperName) {
        return AhaEasyMilestonesService.markComplete(recordId, milestoneDeveloperName);
    }
}
