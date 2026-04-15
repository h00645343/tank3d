using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public sealed class TankAI : MonoBehaviour
{
    public Transform player;
    public Transform turret;
    public Transform firePoint;
    public Projectile projectilePrefab;
    public Vector3[] patrolPoints = new Vector3[0];
    public float moveSpeed = 5f;
    public float turnSpeed = 100f;
    public float detectionRange = 18f;
    public float attackRange = 14f;
    public float fireInterval = 1.2f;
    public float projectileDamage = 18f;
    public float projectileSpeed = 22f;

    Rigidbody body;
    TankHealth health;
    int patrolIndex;
    float nextFireTime;

    void Awake()
    {
        body = GetComponent<Rigidbody>();
        body.constraints = RigidbodyConstraints.FreezeRotationX | RigidbodyConstraints.FreezeRotationZ;
        health = GetComponent<TankHealth>();
    }

    void Update()
    {
        if (health != null && health.IsDead)
        {
            return;
        }

        AimAtTarget();

        if (CanSeePlayer() && Vector3.Distance(transform.position, player.position) <= attackRange)
        {
            TryFire();
        }
    }

    void FixedUpdate()
    {
        if (health != null && health.IsDead)
        {
            return;
        }

        Vector3 destination = GetDestination();
        MoveToward(destination);
    }

    Vector3 GetDestination()
    {
        if (player != null && Vector3.Distance(transform.position, player.position) <= detectionRange)
        {
            return player.position;
        }

        if (patrolPoints == null || patrolPoints.Length == 0)
        {
            return transform.position;
        }

        Vector3 target = patrolPoints[patrolIndex];
        if (Vector3.Distance(transform.position, target) <= 1.2f)
        {
            patrolIndex = (patrolIndex + 1) % patrolPoints.Length;
            target = patrolPoints[patrolIndex];
        }

        return target;
    }

    void MoveToward(Vector3 destination)
    {
        Vector3 direction = destination - transform.position;
        direction.y = 0f;

        if (direction.sqrMagnitude <= 0.25f)
        {
            return;
        }

        Quaternion targetRotation = Quaternion.LookRotation(direction.normalized, Vector3.up);
        body.MoveRotation(Quaternion.RotateTowards(body.rotation, targetRotation, turnSpeed * Time.fixedDeltaTime));
        body.MovePosition(body.position + transform.forward * (moveSpeed * Time.fixedDeltaTime));
    }

    void AimAtTarget()
    {
        if (player == null || turret == null)
        {
            return;
        }

        Vector3 direction = player.position - turret.position;
        direction.y = 0f;

        if (direction.sqrMagnitude > 0.001f)
        {
            turret.rotation = Quaternion.RotateTowards(turret.rotation, Quaternion.LookRotation(direction.normalized, Vector3.up), turnSpeed * Time.deltaTime * 2f);
        }
    }

    bool CanSeePlayer()
    {
        if (player == null || firePoint == null)
        {
            return false;
        }

        Vector3 origin = firePoint.position;
        Vector3 target = player.position + Vector3.up * 0.5f;
        Vector3 direction = target - origin;

        if (Physics.Raycast(origin, direction.normalized, out RaycastHit hit, attackRange))
        {
            return hit.collider.GetComponentInParent<TankController>() != null;
        }

        return false;
    }

    void TryFire()
    {
        if (projectilePrefab == null || firePoint == null || Time.time < nextFireTime)
        {
            return;
        }

        nextFireTime = Time.time + fireInterval;
        Projectile projectile = Instantiate(projectilePrefab, firePoint.position, firePoint.rotation);
        projectile.Init(gameObject, projectileDamage, projectileSpeed);
        projectile.gameObject.SetActive(true);

        foreach (Collider ownCollider in GetComponentsInChildren<Collider>())
        {
            Collider projectileCollider = projectile.GetComponent<Collider>();
            if (projectileCollider != null)
            {
                Physics.IgnoreCollision(ownCollider, projectileCollider);
            }
        }
    }
}
