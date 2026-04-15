using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public sealed class TankController : MonoBehaviour
{
    public float moveSpeed = 8f;
    public float turnSpeed = 110f;
    public float fireCooldown = 0.45f;
    public float projectileDamage = 25f;
    public float projectileSpeed = 26f;
    public Transform turret;
    public Transform firePoint;
    public Projectile projectilePrefab;
    public LayerMask aimMask = ~0;

    Rigidbody body;
    Camera mainCamera;
    float moveInput;
    float turnInput;
    float nextFireTime;
    float speedMultiplier = 1f;
    float damageMultiplier = 1f;

    public float SpeedMultiplier => speedMultiplier;
    public float DamageMultiplier => damageMultiplier;

    void Awake()
    {
        body = GetComponent<Rigidbody>();
        body.constraints = RigidbodyConstraints.FreezeRotationX | RigidbodyConstraints.FreezeRotationZ;
        mainCamera = Camera.main;
    }

    void Update()
    {
        moveInput = Input.GetAxisRaw("Vertical");
        turnInput = Input.GetAxisRaw("Horizontal");

        AimTurretAtMouse();

        if (Input.GetMouseButton(0))
        {
            TryFire();
        }
    }

    void FixedUpdate()
    {
        Vector3 movement = transform.forward * (moveInput * moveSpeed * speedMultiplier * Time.fixedDeltaTime);
        body.MovePosition(body.position + movement);

        Quaternion turn = Quaternion.Euler(0f, turnInput * turnSpeed * Time.fixedDeltaTime, 0f);
        body.MoveRotation(body.rotation * turn);
    }

    public void ApplySpeedMultiplier(float multiplier)
    {
        speedMultiplier = Mathf.Max(0.1f, multiplier);
    }

    public void ApplyDamageMultiplier(float multiplier)
    {
        damageMultiplier = Mathf.Max(0.1f, multiplier);
    }

    public void ResetSpeedMultiplier()
    {
        speedMultiplier = 1f;
    }

    public void ResetDamageMultiplier()
    {
        damageMultiplier = 1f;
    }

    public void TryFire()
    {
        if (projectilePrefab == null || firePoint == null || Time.time < nextFireTime)
        {
            return;
        }

        nextFireTime = Time.time + fireCooldown;
        Projectile projectile = Instantiate(projectilePrefab, firePoint.position, firePoint.rotation);
        projectile.Init(gameObject, projectileDamage * damageMultiplier, projectileSpeed);
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

    void AimTurretAtMouse()
    {
        if (turret == null)
        {
            return;
        }

        if (mainCamera == null)
        {
            mainCamera = Camera.main;
        }

        if (mainCamera == null)
        {
            return;
        }

        Ray ray = mainCamera.ScreenPointToRay(Input.mousePosition);
        Plane ground = new Plane(Vector3.up, Vector3.zero);
        if (ground.Raycast(ray, out float enter))
        {
            Vector3 point = ray.GetPoint(enter);
            Vector3 direction = point - turret.position;
            direction.y = 0f;

            if (direction.sqrMagnitude > 0.001f)
            {
                turret.rotation = Quaternion.LookRotation(direction.normalized, Vector3.up);
            }
        }
    }
}
