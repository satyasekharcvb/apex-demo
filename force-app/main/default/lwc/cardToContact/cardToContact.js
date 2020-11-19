import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createRecord from '@salesforce/apex/RecordCreationHelper.createRecord'


export default class CardToContact extends LightningElement {
    sobject='Contact'

    get options() {
        return [
            { label: 'Contact', value: 'Contact' },
            { label: 'Lead', value: 'Lead' }
        ];
    }

    handleObjectChange(event) {
        this.sobject = event.detail.value;
    }

    get acceptedFormats() {
        return ['.jpg', '.png'];
    }

    handleUploadFinished(event) {
        // Get the list of uploaded files
        const uploadedFiles = event.detail.files;
        
        createRecord({ objectName: this.sobject, contentDocumentId: uploadedFiles[0].documentId })
            .then((result) => {
                const evt = new ShowToastEvent({
                    title: 'Record created successfully',
                    message: 'Record created with record Id ' + result,
                    variant: 'success'
                });
                this.dispatchEvent(evt);
            }).catch((error) => {
                console.log(error.body.message);
                const evt = new ShowToastEvent({
                    title: 'Record creation error',
                    message: error.body.message,
                    variant: 'error'
                });
                this.dispatchEvent(evt);
            });
    }
}