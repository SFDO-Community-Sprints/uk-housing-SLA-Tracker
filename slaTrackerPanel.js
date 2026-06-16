import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getMilestones from '@salesforce/apex/SlaMilestoneController.getMilestones';
import markComplete from '@salesforce/apex/SlaMilestoneController.markComplete';

export default class SlaMilestonePanel extends LightningElement {
    @api recordId;

    @api cardTitle = 'SLA Milestones';
    @api cardIconName = 'standard:entitlement_policy';
    @api iconBackgroundColor = '#2e844a';
    @api iconColor = '#ffffff';
    @api completionActionStyle = 'link';

    @track milestones = [];
    @track panelMessage;
    @track isLoading = false;

    wiredPanelResult;
    timerHandle;
    refreshHandle;

    @wire(getMilestones, { recordId: '$recordId' })
    wiredPanel(value) {
        this.wiredPanelResult = value;
        const { data, error } = value;

        if (data) {
            this.panelMessage = data.message;
            this.milestones = this.decorateMilestones(data.milestones || []);
            this.startTicker();
            this.startRefreshLoop();
        } else if (error) {
            this.panelMessage = this.reduceError(error);
            this.milestones = [];
            this.stopTicker();
            this.stopRefreshLoop();
        }
    }

    connectedCallback() {
        this.startTicker();
        this.startRefreshLoop();
    }

    renderedCallback() {
        this.template.host.style.setProperty('--sla-icon-bg', this.iconBackgroundColor || '#2e844a');
        this.template.host.style.setProperty('--sla-icon-color', this.iconColor || '#ffffff');
    }

    disconnectedCallback() {
        this.stopTicker();
        this.stopRefreshLoop();
    }

    get hasMilestones() {
        return Array.isArray(this.milestones) && this.milestones.length > 0;
    }

    get isButtonStyle() {
        return (this.completionActionStyle || 'link').toLowerCase() === 'button';
    }

    startTicker() {
        this.stopTicker();

        this.timerHandle = window.setInterval(() => {
            this.milestones = this.milestones.map((item) => {
                let nextRemaining = item.remainingMilliseconds;

                if (
                    !item.completed &&
                    nextRemaining !== null &&
                    nextRemaining !== undefined &&
                    item.businessTimeRunning
                ) {
                    if (nextRemaining > 0) {
                        nextRemaining = Math.max(0, nextRemaining - 1000);
                    } else {
                        nextRemaining = nextRemaining - 1000;
                    }
                }

                const updatedItem = {
                    ...item,
                    remainingMilliseconds: nextRemaining
                };

                const updatedStatus = this.computeStatus(updatedItem);

                return {
                    ...updatedItem,
                    status: updatedStatus,
                    liveDisplayText: this.computeDisplayText(updatedItem, updatedStatus),
                    timeClass: this.getTimeClass(updatedStatus),
                    indicatorClass: this.getIndicatorClass(updatedStatus),
                    showCompleteAction: updatedItem.manualCompletionEnabled && !updatedItem.completed
                };
            });
        }, 1000);
    }

    stopTicker() {
        if (this.timerHandle) {
            window.clearInterval(this.timerHandle);
            this.timerHandle = null;
        }
    }

    startRefreshLoop() {
        this.stopRefreshLoop();

        this.refreshHandle = window.setInterval(async () => {
            if (this.wiredPanelResult) {
                try {
                    await refreshApex(this.wiredPanelResult);
                } catch (error) {
                    // Leave the current display in place until the next successful refresh.
                }
            }
        }, 30000);
    }

    stopRefreshLoop() {
        if (this.refreshHandle) {
            window.clearInterval(this.refreshHandle);
            this.refreshHandle = null;
        }
    }

    async handleManualRefresh() {
        if (this.isLoading) {
            return;
        }
        this.isLoading = true;
        try {
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            if (this.wiredPanelResult) {
                await refreshApex(this.wiredPanelResult);
            }
        } catch (error) {
            this.panelMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    decorateMilestones(items) {
        return items.map((item) => {
            const status = this.computeStatus(item);
            return {
                ...item,
                status,
                liveDisplayText: this.computeDisplayText(item, status),
                timeClass: this.getTimeClass(status),
                indicatorClass: this.getIndicatorClass(status),
                showCompleteAction: item.manualCompletionEnabled && !item.completed
            };
        });
    }

    computeStatus(item) {
        if (item.completed) {
            return 'Completed';
        }

        if (item.remainingMilliseconds === null || item.remainingMilliseconds === undefined) {
            return 'Pending';
        }

        return item.remainingMilliseconds < 0 ? 'Overdue' : 'Active';
    }

    computeDisplayText(item, status) {
        if (item.completed) {
            return 'Completed';
        }

        if (item.remainingMilliseconds === null || item.remainingMilliseconds === undefined) {
            return 'Awaiting start';
        }

        const absSeconds = Math.floor(Math.abs(item.remainingMilliseconds) / 1000);

        const secondsPerDay = item.usesBusinessHours ? 8 * 60 * 60 : 24 * 60 * 60;
        const days = Math.floor(absSeconds / secondsPerDay);
        const remainingAfterDays = absSeconds % secondsPerDay;

        const hours = Math.floor(remainingAfterDays / 3600);
        const minutes = Math.floor((remainingAfterDays % 3600) / 60);
        const seconds = remainingAfterDays % 60;

        const hh = String(hours).padStart(2, '0');
        const mm = String(minutes).padStart(2, '0');
        const ss = String(seconds).padStart(2, '0');

        if (status === 'Overdue') {
            return `${days}d ${hh}:${mm}:${ss} overdue`;
        }

        if (status === 'Active') {
            return `${days}d ${hh}:${mm}:${ss} remaining`;
        }

        return 'Awaiting start';
    }

    getTimeClass(status) {
        switch ((status || '').toLowerCase()) {
            case 'completed':
                return 'milestone-time milestone-time_completed';
            case 'overdue':
                return 'milestone-time milestone-time_overdue';
            case 'active':
                return 'milestone-time milestone-time_active';
            default:
                return 'milestone-time milestone-time_pending';
        }
    }

    getIndicatorClass(status) {
        switch ((status || '').toLowerCase()) {
            case 'completed':
                return 'status-indicator status-indicator_completed';
            case 'overdue':
                return 'status-indicator status-indicator_overdue';
            case 'active':
                return 'status-indicator status-indicator_active';
            default:
                return 'status-indicator status-indicator_pending';
        }
    }

    async handleMarkComplete(event) {
        const milestoneDeveloperName = event.currentTarget.dataset.key;
        this.isLoading = true;

        try {
            const result = await markComplete({
                recordId: this.recordId,
                milestoneDeveloperName
            });

            this.panelMessage = result?.message;
            this.milestones = this.decorateMilestones(result?.panel?.milestones || []);
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            await refreshApex(this.wiredPanelResult);
        } catch (error) {
            this.panelMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (!error) {
            return 'Unknown error';
        }

        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }

        return error.body?.message || error.message || 'Unknown error';
    }
}
