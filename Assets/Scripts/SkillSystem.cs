using UnityEngine;

public enum TankSkill
{
    SpeedBoost,
    Shield,
    PowerShot
}

[DisallowMultipleComponent]
public sealed class SkillSystem : MonoBehaviour
{
    public TankController controller;
    public TankHealth health;

    public float speedMultiplier = 1.65f;
    public float speedDuration = 6f;
    public float speedCooldown = 12f;

    public float shieldDamageMultiplier = 0.25f;
    public float shieldDuration = 5f;
    public float shieldCooldown = 14f;

    public float powerShotMultiplier = 2.5f;
    public float powerShotDuration = 7f;
    public float powerShotCooldown = 16f;

    readonly SkillRuntime[] skills =
    {
        new SkillRuntime(TankSkill.SpeedBoost),
        new SkillRuntime(TankSkill.Shield),
        new SkillRuntime(TankSkill.PowerShot)
    };

    void Awake()
    {
        if (controller == null)
        {
            controller = GetComponent<TankController>();
        }

        if (health == null)
        {
            health = GetComponent<TankHealth>();
        }
    }

    void Update()
    {
        TickSkills();

        if (Input.GetKeyDown(KeyCode.Q))
        {
            TryActivate(TankSkill.SpeedBoost);
        }

        if (Input.GetKeyDown(KeyCode.E))
        {
            TryActivate(TankSkill.Shield);
        }

        if (Input.GetKeyDown(KeyCode.R))
        {
            TryActivate(TankSkill.PowerShot);
        }
    }

    public bool TryActivate(TankSkill skill)
    {
        SkillRuntime runtime = GetRuntime(skill);
        if (runtime == null || !runtime.CanActivate)
        {
            return false;
        }

        switch (skill)
        {
            case TankSkill.SpeedBoost:
                runtime.Activate(speedDuration, speedCooldown);
                if (controller != null)
                {
                    controller.ApplySpeedMultiplier(speedMultiplier);
                }
                break;
            case TankSkill.Shield:
                runtime.Activate(shieldDuration, shieldCooldown);
                if (health != null)
                {
                    health.DamageMultiplier = shieldDamageMultiplier;
                }
                break;
            case TankSkill.PowerShot:
                runtime.Activate(powerShotDuration, powerShotCooldown);
                if (controller != null)
                {
                    controller.ApplyDamageMultiplier(powerShotMultiplier);
                }
                break;
        }

        return true;
    }

    public float GetCooldown01(TankSkill skill)
    {
        SkillRuntime runtime = GetRuntime(skill);
        return runtime == null ? 0f : runtime.Cooldown01;
    }

    public float GetRemainingCooldown(TankSkill skill)
    {
        SkillRuntime runtime = GetRuntime(skill);
        return runtime == null ? 0f : Mathf.Max(0f, runtime.cooldownEnd - Time.time);
    }

    public bool IsActive(TankSkill skill)
    {
        SkillRuntime runtime = GetRuntime(skill);
        return runtime != null && runtime.IsActive;
    }

    void TickSkills()
    {
        foreach (SkillRuntime runtime in skills)
        {
            if (runtime.IsActive && Time.time >= runtime.activeEnd)
            {
                Deactivate(runtime.skill);
                runtime.IsActive = false;
            }
        }
    }

    void Deactivate(TankSkill skill)
    {
        switch (skill)
        {
            case TankSkill.SpeedBoost:
                if (controller != null)
                {
                    controller.ResetSpeedMultiplier();
                }
                break;
            case TankSkill.Shield:
                if (health != null)
                {
                    health.DamageMultiplier = 1f;
                }
                break;
            case TankSkill.PowerShot:
                if (controller != null)
                {
                    controller.ResetDamageMultiplier();
                }
                break;
        }
    }

    SkillRuntime GetRuntime(TankSkill skill)
    {
        foreach (SkillRuntime runtime in skills)
        {
            if (runtime.skill == skill)
            {
                return runtime;
            }
        }

        return null;
    }

    sealed class SkillRuntime
    {
        public readonly TankSkill skill;
        public bool IsActive;
        public float activeEnd;
        public float cooldownEnd;
        float cooldownDuration;

        public SkillRuntime(TankSkill skill)
        {
            this.skill = skill;
        }

        public bool CanActivate => Time.time >= cooldownEnd;
        public float Cooldown01 => cooldownDuration <= 0f ? 0f : Mathf.Clamp01((cooldownEnd - Time.time) / cooldownDuration);

        public void Activate(float duration, float cooldown)
        {
            IsActive = true;
            activeEnd = Time.time + duration;
            cooldownDuration = cooldown;
            cooldownEnd = Time.time + cooldown;
        }
    }
}
