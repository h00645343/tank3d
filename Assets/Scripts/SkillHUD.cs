using UnityEngine;
using UnityEngine.UI;

public sealed class SkillHUD : MonoBehaviour
{
    public SkillSystem skillSystem;
    public Image speedFill;
    public Image shieldFill;
    public Image powerFill;
    public Text speedText;
    public Text shieldText;
    public Text powerText;

    void Update()
    {
        if (skillSystem == null)
        {
            return;
        }

        UpdateSlot(TankSkill.SpeedBoost, speedFill, speedText, "Q Speed");
        UpdateSlot(TankSkill.Shield, shieldFill, shieldText, "E Shield");
        UpdateSlot(TankSkill.PowerShot, powerFill, powerText, "R Power");
    }

    void UpdateSlot(TankSkill skill, Image fill, Text label, string readyLabel)
    {
        float cooldown = skillSystem.GetRemainingCooldown(skill);
        bool active = skillSystem.IsActive(skill);

        if (fill != null)
        {
            fill.fillAmount = skillSystem.GetCooldown01(skill);
            fill.color = active ? new Color(0.25f, 0.8f, 1f, 0.75f) : new Color(0f, 0f, 0f, 0.55f);
        }

        if (label != null)
        {
            label.text = cooldown > 0.05f ? readyLabel + "\n" + cooldown.ToString("0.0") + "s" : readyLabel + "\nReady";
        }
    }
}
