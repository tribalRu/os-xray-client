<?php

namespace OPNsense\XrayClient;

use OPNsense\Base\IndexController as BaseIndexController;

class IndexController extends BaseIndexController
{
    public function indexAction()
    {
        $this->view->generalForm = $this->getForm("general");
        // Settings that belong to the Balancers and DNS Servers tabs. They stay
        // fields of the general model node (same ids and storage); only the
        // form they are rendered in differs.
        $this->view->observatoryForm = $this->getForm("generalObservatory");
        $this->view->dnsForm = $this->getForm("generalDns");
        $this->view->formDialogNode = $this->getForm("dialogNode");
        $this->view->formDialogRule = $this->getForm("dialogRule");
        $this->view->formDialogBalancer = $this->getForm("dialogBalancer");
        $this->view->formDialogDnsServer = $this->getForm("dialogDnsServer");
        $this->view->maintenanceForm = $this->getForm("maintenance");
        $this->view->pick('OPNsense/XrayClient/index');
    }
}
