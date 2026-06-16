public with sharing class AhaEasyMilestonesDtos {
    public class PanelDto {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String processDeveloperName;
        @AuraEnabled public String processLabel;
        @AuraEnabled public String message;
        @AuraEnabled public List<MilestoneDto> milestones = new List<MilestoneDto>();
    }

    public class MilestoneDto {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public Integer sequence;
        @AuraEnabled public Boolean manualCompletionEnabled;
        @AuraEnabled public Boolean completed;
        @AuraEnabled public Boolean overdue;
        @AuraEnabled public Boolean businessTimeRunning;
        @AuraEnabled public Boolean usesBusinessHours;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime startDateTime;
        @AuraEnabled public Datetime targetDateTime;
        @AuraEnabled public Long remainingMilliseconds;
        @AuraEnabled public String displayText;
    }

    public class ActionResultDto {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public PanelDto panel;
    }
}
