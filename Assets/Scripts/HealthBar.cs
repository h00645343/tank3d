using UnityEngine;
using UnityEngine.UI;

public sealed class HealthBar : MonoBehaviour
{
    public TankHealth target;
    public Slider slider;
    public Image fill;
    public Color healthyColor = new Color(0.2f, 0.85f, 0.25f);
    public Color hurtColor = new Color(0.95f, 0.2f, 0.15f);
    public bool faceCamera = true;
    bool subscribed;

    void Awake()
    {
        if (slider == null)
        {
            slider = GetComponentInChildren<Slider>();
        }
    }

    void OnEnable()
    {
        Subscribe();
    }

    void Start()
    {
        Subscribe();
    }

    void OnDisable()
    {
        if (target != null && subscribed)
        {
            target.OnHealthChanged -= HandleHealthChanged;
            subscribed = false;
        }
    }

    void LateUpdate()
    {
        if (faceCamera && Camera.main != null)
        {
            transform.rotation = Quaternion.LookRotation(transform.position - Camera.main.transform.position, Vector3.up);
        }
    }

    void HandleHealthChanged(TankHealth health, float current, float max)
    {
        float percent = max <= 0f ? 0f : Mathf.Clamp01(current / max);
        if (slider != null)
        {
            slider.value = percent;
        }

        if (fill != null)
        {
            fill.color = Color.Lerp(hurtColor, healthyColor, percent);
        }
    }

    void Subscribe()
    {
        if (target == null || subscribed)
        {
            return;
        }

        target.OnHealthChanged += HandleHealthChanged;
        subscribed = true;
        HandleHealthChanged(target, target.currentHealth, target.maxHealth);
    }
}
