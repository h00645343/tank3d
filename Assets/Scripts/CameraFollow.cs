using UnityEngine;

[RequireComponent(typeof(Camera))]
public sealed class CameraFollow : MonoBehaviour
{
    public Transform target;
    public Vector3 perspectiveOffset = new Vector3(0f, 13f, -11f);
    public Vector3 orthographicOffset = new Vector3(0f, 22f, -1f);
    public float smoothTime = 0.12f;
    public bool useOrthographic = false;
    public float orthographicSize = 15f;

    Camera followCamera;
    Vector3 velocity;

    void Awake()
    {
        followCamera = GetComponent<Camera>();
    }

    void LateUpdate()
    {
        if (target == null)
        {
            return;
        }

        followCamera.orthographic = useOrthographic;
        followCamera.orthographicSize = orthographicSize;

        Vector3 offset = useOrthographic ? orthographicOffset : perspectiveOffset;
        Vector3 desiredPosition = target.position + offset;
        transform.position = Vector3.SmoothDamp(transform.position, desiredPosition, ref velocity, smoothTime);
        transform.rotation = Quaternion.LookRotation(target.position - transform.position + Vector3.up * 1.5f, Vector3.up);
    }
}
