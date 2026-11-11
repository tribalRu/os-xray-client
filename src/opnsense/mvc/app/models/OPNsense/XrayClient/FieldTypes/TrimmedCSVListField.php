<?php

namespace OPNsense\XrayClient\FieldTypes;

use OPNsense\Base\FieldTypes\CSVListField;

/**
 * Comma-separated list with whitespace trimmed around every entry and empty
 * entries dropped. Commas, semicolons and whitespace are all accepted as
 * separators.
 *
 * The FinalMask fragment rows are edited with the OPNsense tokenizer, which
 * submits clean comma-separated tokens. Values saved by the earlier free-text
 * rows can still contain spaces after the commas ("3-7, 4-9") or use another
 * separator, and a list left empty would otherwise expose one empty option to
 * the edit dialog, so all of this is normalised here. Trimming on write also
 * keeps the per-item mask simple.
 */
class TrimmedCSVListField extends CSVListField
{
    /**
     * Normalise the incoming value: split on the field separator, trim every
     * entry and drop the empty ones.
     *
     * @param mixed $value list or comma-separated string
     * @return void
     */
    public function setValue($value)
    {
        if (is_array($value)) {
            $value = implode($this->internalFieldSeparator, $value);
        }

        // Commas are the separator the tokenizer submits; semicolons and
        // whitespace are accepted as well so lists written for the previous
        // free-text rows keep working.
        $items = [];
        foreach (preg_split('/[,;\s]+/', (string)$value) as $entry) {
            $entry = trim($entry);
            if ($entry !== '') {
                $items[] = $entry;
            }
        }

        parent::setValue(implode($this->internalFieldSeparator, $items));
    }

    /**
     * Return the entries as a key/value list for select_multiple widgets.
     * The parent implementation exposes an empty entry when the list is
     * empty, which the tokenizer would keep selected and submit back.
     *
     * @return array
     */
    public function getNodeData()
    {
        $result = [];
        foreach ($this->getValues() as $entry) {
            $result[$entry] = ['value' => $entry, 'selected' => 1];
        }

        return $result;
    }
}
