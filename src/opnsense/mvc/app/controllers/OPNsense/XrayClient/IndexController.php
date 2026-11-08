<?php

namespace OPNsense\XrayClient;

use OPNsense\Base\IndexController as BaseIndexController;

class IndexController extends BaseIndexController
{
    public function indexAction()
    {
        $this->view->generalForm = $this->getForm("general");
        $this->view->formDialogNode = $this->getForm("dialogNode");
        $this->view->formDialogRule = $this->getForm("dialogRule");
        $this->view->formDialogBalancer = $this->getForm("dialogBalancer");
        $this->view->formDialogDnsServer = $this->getForm("dialogDnsServer");
        $this->view->maintenanceForm = $this->getForm("maintenance");
        $this->view->pick('OPNsense/XrayClient/index');
    }
}
