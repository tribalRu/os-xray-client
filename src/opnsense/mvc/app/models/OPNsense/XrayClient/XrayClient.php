<?php

namespace OPNsense\XrayClient;

use OPNsense\Base\BaseModel;
use OPNsense\Base\Messages\Message;

class XrayClient extends BaseModel
{
    /**
     * Cross-field checks the per-field masks cannot express:
     * - a local proxy with "password" authentication needs a user name and a
     *   password, otherwise Xray starts an inbound nobody can log in to.
     */
    public function performValidation($validateFullModel = false)
    {
        $messages = parent::performValidation($validateFullModel);

        $inbounds = [
            ['enable_socks', 'socks_auth', 'socks_username', 'socks_password'],
            ['enable_http', 'http_auth', 'http_username', 'http_password'],
        ];
        foreach ($inbounds as $names) {
            list($enable, $auth, $user, $pass) = $names;
            if ((string)$this->general->$enable !== '1' || (string)$this->general->$auth !== 'password') {
                continue;
            }
            foreach ([$user, $pass] as $name) {
                if (trim((string)$this->general->$name) === '') {
                    $messages->appendMessage(new Message(
                        gettext('Required when authentication is set to password.'),
                        $this->general->$name->__reference
                    ));
                }
            }
        }

        return $messages;
    }
}
