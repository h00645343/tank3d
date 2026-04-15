using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
[RequireComponent(typeof(Collider))]
public sealed class Projectile : MonoBehaviour
{
    public float damage = 25f;
    public float speed = 24f;
    public float lifeTime = 4f;

    Rigidbody body;
    GameObject owner;
    float spawnTime;

    void Awake()
    {
        body = GetComponent<Rigidbody>();
        body.useGravity = false;
        body.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
    }

    void OnEnable()
    {
        spawnTime = Time.time;
        body.velocity = transform.forward * speed;
    }

    void Update()
    {
        if (Time.time - spawnTime >= lifeTime)
        {
            Destroy(gameObject);
        }
    }

    public void Init(GameObject projectileOwner, float finalDamage, float finalSpeed)
    {
        owner = projectileOwner;
        damage = finalDamage;
        speed = finalSpeed;
    }

    void OnCollisionEnter(Collision collision)
    {
        if (owner != null && collision.transform.root == owner.transform.root)
        {
            return;
        }

        TankHealth health = collision.collider.GetComponentInParent<TankHealth>();
        if (health != null)
        {
            health.TakeDamage(damage);
        }

        Destroy(gameObject);
    }
}
