using System;
using UnityEngine;

[DisallowMultipleComponent]
public sealed class TankHealth : MonoBehaviour
{
    public float maxHealth = 100f;
    public float currentHealth = 100f;
    public bool destroyOnDeath = false;

    public event Action<TankHealth, float, float> OnHealthChanged;
    public event Action<TankHealth> OnDeath;

    public bool IsDead { get; private set; }
    public float DamageMultiplier { get; set; } = 1f;
    public float HealthPercent => maxHealth <= 0f ? 0f : Mathf.Clamp01(currentHealth / maxHealth);

    void Awake()
    {
        currentHealth = Mathf.Clamp(currentHealth <= 0f ? maxHealth : currentHealth, 0f, maxHealth);
    }

    void Start()
    {
        OnHealthChanged?.Invoke(this, currentHealth, maxHealth);
    }

    public void TakeDamage(float amount)
    {
        if (IsDead || amount <= 0f)
        {
            return;
        }

        currentHealth = Mathf.Max(0f, currentHealth - amount * Mathf.Max(0f, DamageMultiplier));
        OnHealthChanged?.Invoke(this, currentHealth, maxHealth);

        if (currentHealth <= 0f)
        {
            Die();
        }
    }

    public void Heal(float amount)
    {
        if (IsDead || amount <= 0f)
        {
            return;
        }

        currentHealth = Mathf.Min(maxHealth, currentHealth + amount);
        OnHealthChanged?.Invoke(this, currentHealth, maxHealth);
    }

    public void Die()
    {
        if (IsDead)
        {
            return;
        }

        IsDead = true;
        OnDeath?.Invoke(this);

        if (destroyOnDeath)
        {
            Destroy(gameObject, 0.25f);
        }
    }
}
